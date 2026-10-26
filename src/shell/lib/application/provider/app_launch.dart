import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/provider/logs_for_pid.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/meta_window/provider/process_info_state.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:uuid/uuid.dart';

part 'app_launch.g.dart';

/// systemd unit name prefix identifying every launch of [trackedWindowId]:
/// `veshell-launch-<tile-uuid>-`. The trailing `-` separates it from the
/// per-launch suffix, so matching the prefix never collides with another
/// tile's (full, fixed-length) uuid.
String _launchUnitPrefix(WindowId trackedWindowId) =>
    'veshell-launch-${_windowKey(trackedWindowId)}-';

String _windowKey(WindowId windowId) => switch (windowId) {
  DialogWindowId(:final uuid) => uuid,
  PersistentWindowId(:final uuid) => uuid,
  EphemeralWindowId(:final uuid) => uuid,
};

/// Builds the `systemd-run` argv for a tracked launch.
///
/// Public for tests. The working directory and application argv are passed as
/// discrete arguments: a saved path or document can never be interpreted by a
/// shell. Custom exec launches keep their shell-form command.
List<String> buildTrackedLaunchArguments({
  required LaunchConfig config,
  required String unitName,
  required Map<String, String> environment,
  String? fallbackWorkingDirectory,
}) {
  return [
    // The whole lifecycle runs under the *user* manager of this uid.
    '--user',
    '--quiet',
    // Forward service stdio to this process, so the shell-side execution
    // log viewer shows the application's output.
    '--pipe',
    // Stay alive until the service stops, so the placeholder's execution
    // log viewer and waiting state track the application's lifetime.
    // Attribution does *not* depend on this process exiting: it is keyed
    // by the unit cgroup and outlives the supervisor (see below).
    '--wait',
    // Transient unit immediately garbage-collected after exit — no
    // stale "veshell-launch-*" units in `systemctl --user`.
    '--collect',
    // Consider the service finished only when the whole cgroup is empty,
    // not when the launcher shell returns: steam-style bootstrappers that
    // re-exec games keep the launch attributed while children live on.
    '--property=ExitType=cgroup',
    // The user manager does not inherit the compositor's cwd. A resume launch
    // passes the tile's saved directory here; it is one argv element, never
    // interpolated.
    '--working-directory='
        '${config.workingDirectory ?? fallbackWorkingDirectory ?? Directory.current.path}',
    '--unit=$unitName',
    // Compositor session environment overrides the manager's own (which
    // may still carry values imported by another desktop on this uid:
    // DISPLAY=:0 from GNOME, etc.). PWD/OLDPWD are excluded: they do not
    // describe the service's cwd and conflict with WorkingDirectory.
    ...environment.entries
        .where((entry) => entry.key != 'PWD' && entry.key != 'OLDPWD')
        .map((entry) => '--setenv=${entry.key}=${entry.value}'),
    if (config.argv.isNotEmpty)
      ...config.argv
    else ...[
      '/bin/sh',
      '-c',
      config.command ?? '',
    ],
  ];
}

/// A live tracked launch of one tile: the supervisor process the shell spawned
/// and, for a systemd-managed launch, the transient unit that owns the
/// application's cgroup.
class _Launch {
  _Launch({required this.process, required this.unitName});

  final Process process;

  /// The `systemd-run` transient unit name, or `null` for the untracked
  /// fallback (no user manager), where the shell owns [process] directly.
  final String? unitName;

  /// Whether a native window was attributed to this tile from this launch.
  /// Once true the launch is no longer "pending": the application is up and
  /// closing its window is what makes it exit.
  bool producedWindow = false;
}

/// Single launch entry point of the compositor.
///
/// Every application started by the shell runs inside a disposable systemd
/// user service named after the launching tile:
/// `veshell-launch-<tile-uuid>-<launch-suffix>.service`. Descendants inherit
/// the cgroup, so the association survives helper processes, `exec` and
/// launcher wrappers exiting — which is how a placeholder "knows" that
/// windows reported afterwards belong to its application even when they
/// surface unrelated ids (`steamwebhelper`, Electron runtimes, games started
/// from Steam).
///
/// The tile uuid inside the unit name is what makes attribution stable across
/// relaunches and shell restarts, without any lookup table: [windowForPid]
/// recognizes the tile from the process cgroup alone. A single-instance
/// application that keeps running in the cgroup of its *first* launch therefore
/// stays attributable when the tile relaunches it later (the new launch only
/// asks the running instance to open a window), and after a shell restart the
/// prefix is recomputed from the persisted tile. The suffix only has to keep
/// concurrent launches of the same tile distinct for `systemd-run`.
///
/// Attribution is never a security boundary — cgroups are user-visible and
/// pids are recycled — it is only matching evidence.
@Riverpod(keepAlive: true)
class AppLaunch extends _$AppLaunch {
  /// Tracked launches by the tile that started them, so a tile that is removed
  /// while still starting can cancel its own launch and a re-launch replaces
  /// the previous entry.
  final Map<WindowId, _Launch> _launches = {};

  @override
  void build() {}

  Future<Process> launchApplication(
    LaunchConfig config, {
    required WindowId trackedWindowId,
  }) async {
    final launch = await _launchTracked(config, trackedWindowId);
    ref
        .read(logsForPidProvider(launch.process.pid).notifier)
        .setProcess(launch.process, command: config.displayCommand);
    _launches[trackedWindowId] = launch;
    // A `--wait` supervisor exits when its unit stops, so once it is gone there
    // is nothing left to cancel. A relaunch installs a fresh entry; only clear
    // the one this process owns.
    unawaited(
      launch.process.exitCode.then((_) {
        if (identical(_launches[trackedWindowId], launch)) {
          _launches.remove(trackedWindowId);
        }
      }),
    );
    return launch.process;
  }

  /// Marks [windowId]'s launch as having produced a native window, so removing
  /// the tile no longer cancels it.
  void markProducedWindow(WindowId windowId) {
    _launches[windowId]?.producedWindow = true;
  }

  /// Whether [windowId]'s launch is still running.
  ///
  /// The tracked launch lives as long as the application does (`systemd-run
  /// --wait` exits with its cgroup), so a tile that lost its window can use
  /// this to tell an application that is about to open a replacement surface
  /// from one that is already gone.
  bool hasLiveLaunch(WindowId windowId) => _launches.containsKey(windowId);

  /// Cancels the launch of [windowId] if it never produced a native window.
  ///
  /// Called when a tile is removed. A tile that displayed a window already
  /// handed the application off — closing that window is what makes it exit —
  /// so only a tile still waiting on its first surface cancels its startup,
  /// preventing a stuck launch from lingering. The unit is stopped through the
  /// user manager (`systemctl --user stop` sends SIGTERM to the cgroup) rather
  /// than by killing the `systemd-run` supervisor, which does not own the
  /// application. A launch whose process is already showing a window under
  /// another tile is left running.
  void cancelPendingLaunch(WindowId windowId) {
    final launch = _launches.remove(windowId);
    if (launch == null || launch.producedWindow) {
      return;
    }
    final unitName = launch.unitName;
    if (unitName == null) {
      launch.process.kill();
      return;
    }
    if (_unitHasOwnedWindow(unitName)) {
      return;
    }
    unawaited(
      Process.run('systemctl', [
        '--user',
        'stop',
        '--no-block',
        '$unitName.service',
      ]),
    );
  }

  /// Whether any tile currently owns a native window from [unitName]'s cgroup.
  ///
  /// Guards [cancelPendingLaunch] against a launch whose window was attributed
  /// elsewhere (e.g. provenance rejected as an unrelated application): stopping
  /// the unit would tear down a window that is on screen.
  bool _unitHasOwnedWindow(String unitName) {
    final processInfo = ref.read(processInfoStateProvider.notifier);
    for (final metaWindowId in ref.read(metaWindowWindowMapProvider).keys) {
      final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));
      final cgroup = processInfo.forPid(metaWindow.pid)?.cgroup;
      if (cgroup != null && cgroup.contains('/$unitName')) {
        return true;
      }
    }
    return false;
  }

  /// Plain exec fallback for systems without a systemd user manager: the
  /// application is launched the historical way, without launch attribution.
  ///
  /// Only used in two cases for tracked launches, both detectable *before*
  /// the application process exists — so the fallback can never spawn a
  /// duplicate:
  ///
  /// - the user manager is not reachable ([_isUserSystemdAvailable]), or
  /// - `systemd-run` itself cannot be spawned (missing binary, see the
  ///   `on ProcessException` below).
  ///
  /// A supervision that dies while *starting* the unit (bad
  /// `--working-directory`, option clash, journal `200/CHDIR` style errors)
  /// is not covered: the app was spawned through systemd-run and could have
  /// started, so silently retrying would risk two instances. Such failures
  /// surface as `process exited with code N` in the placeholder's
  /// execution logs instead.
  Future<Process> _launchStandard(LaunchConfig config) {
    final workingDirectory = config.workingDirectory;
    if (config.argv.isNotEmpty) {
      return Process.start(
        config.argv.first,
        config.argv.skip(1).toList(),
        workingDirectory: workingDirectory,
      );
    }
    return Process.start('/bin/sh', [
      '-c',
      config.command ?? '',
    ], workingDirectory: workingDirectory);
  }

  Future<_Launch> _launchTracked(
    LaunchConfig config,
    WindowId trackedWindowId,
  ) async {
    // Without a running systemd user manager there is nothing to track: the
    // application would never be attributed to a cgroup by this launch, and
    // window matching would behave exactly like the untracked fallback — so
    // launching untracked is strictly equivalent here.
    if (!_isUserSystemdAvailable()) {
      return _Launch(process: await _launchStandard(config), unitName: null);
    }

    // The user manager has its own session environment (set by whichever
    // graphical session imported it last); it must not be relied upon.
    // [PlatformManager.fetchLaunchEnvironment] returns the compositor's
    // current environment, which is forwarded verbatim to the service so
    // tracked applications observe `WAYLAND_DISPLAY`/`DISPLAY` as seen by
    // this compositor, never the value of a parallel GNOME session.
    final environment = await ref
        .read(platformManagerProvider.notifier)
        .fetchLaunchEnvironment();
    // The tile uuid is the stable part; the short suffix only makes this
    // particular launch's unit unique for `systemd-run` (a unit name cannot be
    // reused while it is still active).
    final unitName =
        '${_launchUnitPrefix(trackedWindowId)}'
        '${const Uuid().v4().substring(0, 8)}';
    late final Process process;
    try {
      process = await Process.start(
        'systemd-run',
        buildTrackedLaunchArguments(
          config: config,
          unitName: unitName,
          environment: environment,
        ),
        environment: environment,
      );
    } on ProcessException catch (error) {
      print('Tracked launch unavailable, using standard launch: $error');
      return _Launch(process: await _launchStandard(config), unitName: null);
    }

    return _Launch(process: process, unitName: unitName);
  }

  /// Resolves a process back to the placeholder that launched it by matching
  /// its unified cgroup membership, reported by the compositor in the pid
  /// table (`process_info`), against every tile's launch prefix.
  ///
  /// The prefix is derived from the persisted tile id, so this needs no lookup
  /// table and keeps working after a shell restart and across relaunches: a
  /// single-instance application keeps the cgroup of its first launch even
  /// when the tile launches it again.
  ///
  /// Returns null when the pid is unmapped, its process already exited
  /// (common for bootstrappers that hand windows over and exit), the window's
  /// cgroup is unknown, or the process migrated out of the launch cgroup
  /// (e.g. applications re-homing into `app-*.scope`). Null simply means "no
  /// attribution available" — the caller keeps its ordinary matching result.
  WindowId? windowForPid(int pid) {
    final cgroupPath = ref
        .read(processInfoStateProvider.notifier)
        .forPid(pid)
        ?.cgroup;
    if (cgroupPath == null) return null;

    for (final windowId in ref.read(windowManagerProvider).windows) {
      if (cgroupPath.contains('/${_launchUnitPrefix(windowId)}')) {
        return windowId;
      }
    }
    return null;
  }

  /// Whether a systemd user manager is reachable, detected through its
  /// runtime socket rather than spawning anything. Checked on every tracked
  /// launch: a manager may appear or disappear between sessions on the same
  /// uid, so the result is deliberately not cached.
  bool _isUserSystemdAvailable() {
    final runtimeDirectory = Platform.environment['XDG_RUNTIME_DIR'];
    if (runtimeDirectory == null) {
      return false;
    }
    return File('$runtimeDirectory/systemd/private').existsSync();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/provider/logs_for_pid.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:uuid/uuid.dart';

part 'app_launch.g.dart';

/// Single launch entry point of the compositor.
///
/// Every application started by the shell runs inside a disposable systemd
/// user service named `veshell-launch-<uuid>.service` whose cgroup is
/// registered here for launch attribution. Descendants inherit the cgroup,
/// so the association survives helper processes, `exec` and launcher
/// wrappers exiting — which is how a placeholder "knows" that windows
/// reported afterwards belong to its application even when they surface
/// unrelated ids (`steamwebhelper`, Electron runtimes, games started from
/// Steam).
///
/// Lifecycle of an association:
///
/// 1. [launchApplication] spawns `systemd-run --user --wait` and registers
///    `(trackedWindowId → unitName)`.
/// 2. [windowForPid] resolves native window pids back to the placeholder via
///    `/proc/<pid>/cgroup`, consulted by the matching engine as a last
///    resort when ordinary app-id matching finds nothing.
/// 3. The association is dropped when the tracked service stops (`--wait`
///    makes the spawned process exit signal the end), or eagerly through
///    [forgetWindow] to prevent a removed placeholder from adopting windows
///    afterwards. A relaunch replaces the previous association.
///
/// Attribution is never a security boundary — cgroups are user-visible and
/// pids are recycled — it is only matching evidence.
@Riverpod(keepAlive: true)
class AppLaunch extends _$AppLaunch {
  final Map<WindowId, _TrackedLaunch> _trackedLaunches = {};

  @override
  void build() {}

  Future<Process> launchApplication(
    LaunchConfig config, {
    required WindowId trackedWindowId,
  }) async {
    final process = await _launchTracked(config, trackedWindowId);
    ref.read(logsForPidProvider(process.pid).notifier).setProcess(process);
    return process;
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
    return Process.start('/bin/sh', ['-c', config.command]);
  }

  Future<Process> _launchTracked(
    LaunchConfig config,
    WindowId trackedWindowId,
  ) async {
    // Without a running systemd user manager there is nothing to track: the
    // application would never be attributed to a cgroup by this launch, and
    // window matching would behave exactly like the untracked fallback — so
    // launching untracked is strictly equivalent here.
    if (!_isUserSystemdAvailable()) {
      return _launchStandard(config);
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
    final unitName = 'veshell-launch-${const Uuid().v4()}';
    late final Process process;
    try {
      process = await Process.start('systemd-run', [
        // The whole lifecycle runs under the *user* manager of this uid.
        '--user',
        '--quiet',
        // Forward service stdio to this process, so the shell-side execution
        // log viewer shows the application's output.
        '--pipe',
        // Stay alive until the service stops: process.exitCode below relies
        // on it to clear the launch association exactly when the application
        // (and its descendants, see ExitType) are gone.
        '--wait',
        // Transient unit immediately garbage-collected after exit — no
        // stale "veshell-launch-*" units in `systemctl --user`.
        '--collect',
        // Consider the service finished only when the whole cgroup is empty,
        // not when the launcher shell returns: steam-style bootstrappers that
        // re-exec games keep the launch attributed while children live on.
        '--property=ExitType=cgroup',
        // The user manager does not inherit the compositor's cwd.
        '--working-directory=${Directory.current.path}',
        '--unit=$unitName',
        // Compositor session environment overrides the manager's own (which
        // may still carry values imported by another desktop on this uid:
        // DISPLAY=:0 from GNOME, etc.). PWD/OLDPWD are excluded: they do not
        // describe the service's cwd and conflict with WorkingDirectory.
        ...environment.entries
            .where((entry) => entry.key != 'PWD' && entry.key != 'OLDPWD')
            .map((entry) => '--setenv=${entry.key}=${entry.value}'),
        '/bin/sh',
        '-c',
        config.command,
      ], environment: environment);
    } on ProcessException catch (error) {
      print('Tracked launch unavailable, using standard launch: $error');
      return _launchStandard(config);
    }

    // Keep the launch association for as long as the application is alive.
    // `systemd-run --wait` only exits once the tracked service has stopped,
    // so its exitCode marks the end of the application.
    final launch = _TrackedLaunch(unitName);
    _trackedLaunches[trackedWindowId] = launch;
    unawaited(
      process.exitCode.then((_) {
        if (_trackedLaunches[trackedWindowId] == launch) {
          _trackedLaunches.remove(trackedWindowId);
        }
      }),
    );
    return process;
  }

  /// Resolves a process back to the placeholder that launched it, reading
  /// its unified cgroup membership from `/proc/<pid>/cgroup` and matching it
  /// against the active launch units.
  ///
  /// Returns null when the pid is unmapped, its process already exited
  /// (common for bootstrappers that hand windows over and exit), the window's
  /// cgroup cannot be read, or the process migrated out of the launch cgroup
  /// (e.g. applications re-homing into `app-*.scope`). Null simply means "no
  /// attribution available" — the caller keeps its ordinary matching result.
  WindowId? windowForPid(int pid) {
    final cgroupPath = _cgroupPathForPid(pid);
    if (cgroupPath == null) return null;

    for (final entry in _trackedLaunches.entries) {
      if (cgroupPath.contains('/${entry.value.unitName}.service')) {
        return entry.key;
      }
    }
    return null;
  }

  /// Unified cgroup path of [pid], exposed for launch-attribution
  /// diagnostics.
  String? cgroupPathForPid(int pid) => _cgroupPathForPid(pid);

  /// Removes the launch association of a destroyed placeholder so it can no
  /// longer adopt windows (the application itself keeps running).
  void forgetWindow(WindowId windowId) {
    _trackedLaunches.remove(windowId);
  }

  /// Unified cgroup path of [pid], or null when unreadable: used for
  /// attribution diagnostics ('Matching' log shows the raw path, which also
  /// exposes applications that migrated into `app-*.scope`).
  String? _cgroupPathForPid(int pid) {
    try {
      for (final line in File('/proc/$pid/cgroup').readAsLinesSync()) {
        final separator = line.indexOf('::');
        if (separator != -1) return line.substring(separator + 2);
      }
    } on FileSystemException {
      return null;
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

class _TrackedLaunch {
  _TrackedLaunch(this.unitName);

  final String unitName;
}

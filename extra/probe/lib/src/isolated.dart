import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:veshell_probe/src/connection.dart';

/// The fixture an isolated instance starts with when none is given.
const defaultFixture = 'two-apps';

/// The system data an isolated instance still sees: everything but the
/// installed applications, which the fixture replaces.
const sharedSystemData = ['icons', 'fonts', 'themes', 'mime', 'pixmaps'];

/// The size of a headless instance's display when none is given.
const defaultHeadlessSize = (width: 1280, height: 800);

/// An isolated instance the probe started (see `start`).
class IsolatedInstance {
  IsolatedInstance({
    required this.pid,
    required this.url,
    required this.root,
    required this.fixture,
    required this.log,
    this.hostPid,
    this.busPid,
    this.probeSocket,
    this.size,
  });

  factory IsolatedInstance.fromJson(Map<String, Object?> json) =>
      IsolatedInstance(
        pid: json['pid']! as int,
        url: Uri.parse(json['url']! as String),
        root: json['root']! as String,
        fixture: json['fixture']! as String,
        log: json['log']! as String,
        hostPid: json['hostPid'] as int?,
        busPid: json['busPid'] as int?,
        probeSocket: json['probeSocket'] as String?,
        size: switch (json['size']) {
          {'width': final int width, 'height': final int height} => (
            width: width,
            height: height,
          ),
          _ => null,
        },
      );

  final int pid;
  final Uri url;

  /// The temporary directory holding its configuration and data.
  final String root;
  final String fixture;
  final String log;

  /// The headless compositor the instance is nested in; `null` when it is
  /// a window of the developer's session.
  final int? hostPid;

  /// Its private session bus.
  final int? busPid;

  /// The embedder's control socket, removed with the instance.
  final String? probeSocket;

  /// The headless display's size.
  final ({int width, int height})? size;

  bool get isRunning =>
      isOwnProcess(pid, veshellProcessName, marker: p.basename(root));

  Map<String, Object?> toJson() => {
    'pid': pid,
    'url': '$url',
    'root': root,
    'fixture': fixture,
    'log': log,
    if (hostPid != null) 'hostPid': hostPid,
    if (busPid != null) 'busPid': busPid,
    if (probeSocket != null) 'probeSocket': probeSocket,
    if (size case final size?)
      'size': {'width': size.width, 'height': size.height},
  };
}

/// Where the running isolated instance is recorded.
File instanceFile(String repositoryRoot) =>
    File(p.join(repositoryRoot, 'build', 'probe', 'instance.json'));

/// The recorded isolated instance, when it still runs.
IsolatedInstance? runningIsolatedInstance(String? repositoryRoot) {
  if (repositoryRoot == null) {
    return null;
  }
  final file = instanceFile(repositoryRoot);
  if (!file.existsSync()) {
    return null;
  }
  try {
    final instance = IsolatedInstance.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
    );
    return instance.isRunning ? instance : null;
  } on Object {
    return null;
  }
}

/// The debug build to run: `cargo build` puts it under the configured
/// target directory.
String? findVeshellBinary(String repositoryRoot) {
  for (final candidate in [
    p.join(repositoryRoot, 'build', 'target', 'debug', 'veshell'),
    p.join(repositoryRoot, 'target', 'debug', 'veshell'),
  ]) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

/// The environment of an isolated instance rooted at [root], showing the
/// applications of [fixtureShare]: its own configuration, data, cache and
/// state, user directories (videos, …) inside [root], and only the system's
/// shared data ([sharedSystemData]) besides the fixture.
Map<String, String> isolatedEnvironment({
  required Map<String, String> base,
  required String root,
  required String fixtureShare,
}) {
  String dir(String name) => p.join(root, name);
  return {
      ...base,
      'VESHELL_CONFIG_DIR': dir('config'),
      'XDG_CONFIG_HOME': dir('xdg-config'),
      'XDG_DATA_HOME': dir('xdg-data'),
      'XDG_CACHE_HOME': dir('xdg-cache'),
      'XDG_STATE_HOME': dir('xdg-state'),
      'XDG_DATA_DIRS': '$fixtureShare:${dir('system-share')}',
      // Home-relative paths (the shell reads HOME directly) stay inside too.
      'HOME': dir('home'),
      // A bus of its own: the instance claims session services
      // (notifications, the portal backend) and shows the session's media
      // players, which must be its own, not the developer's.
      'DBUS_SESSION_BUS_ADDRESS': 'unix:path=${dir('bus')}',
      'VESHELL_BACKEND': 'winit',
      // The system bus is the host's (logind, NetworkManager, BlueZ, UPower):
      // the shell only reads it (see the shell's ReadOnlySystemBusClient).
      'VESHELL_PROBE_ISOLATED': '1',
    }
    // Not the developer's login session: nothing session-specific (logind's
    // session, seat or VT) is the instance's to act on.
    ..remove('XDG_SESSION_ID')
    ..remove('XDG_SEAT')
    ..remove('XDG_VTNR')
    // The parent's: the instance announces its own, and must not rewrite
    // the developer's `.vscode/vmService.json`.
    ..remove('VESHELL_VM_SERVICE_URL')
    ..remove('VESHELL_VSCODE_DEBUG');
}

/// Lays out the directories [isolatedEnvironment] points into.
void prepareIsolatedRoot(String root, {String systemShare = '/usr/share'}) {
  for (final name in [
    'config',
    'xdg-config',
    'xdg-data',
    'xdg-cache',
    'xdg-state',
    'system-share',
    'home/Videos',
    'home/Pictures',
    'home/Documents',
    'home/Downloads',
    'home/Music',
    'home/Desktop',
  ]) {
    Directory(p.join(root, name)).createSync(recursive: true);
  }
  // `xdg-user-dirs` looks here for the user directories; without it they
  // fall back to the real home's.
  String home(String name) => p.join(root, 'home', name);
  File(p.join(root, 'xdg-config', 'user-dirs.dirs')).writeAsStringSync(
    [
      'XDG_DESKTOP_DIR="${home('Desktop')}"',
      'XDG_DOWNLOAD_DIR="${home('Downloads')}"',
      'XDG_DOCUMENTS_DIR="${home('Documents')}"',
      'XDG_MUSIC_DIR="${home('Music')}"',
      'XDG_PICTURES_DIR="${home('Pictures')}"',
      'XDG_VIDEOS_DIR="${home('Videos')}"',
      '',
    ].join('\n'),
  );
  for (final name in sharedSystemData) {
    final target = p.join(systemShare, name);
    if (Directory(target).existsSync()) {
      Link(p.join(root, 'system-share', name)).createSync(target);
    }
  }
}

/// Starts an isolated nested instance with [fixture]; waits until it serves
/// the probe.
///
/// [headless] (the default) nests it in a headless Weston of [size]: off
/// the developer's screen, and the same size on every machine, which
/// reference frames need. Otherwise it is a window of the developer's
/// session, sized by its compositor.
Future<IsolatedInstance> startIsolatedInstance({
  required String repositoryRoot,
  String fixture = defaultFixture,
  bool headless = true,
  ({int width, int height}) size = defaultHeadlessSize,
  Duration timeout = const Duration(seconds: 90),
}) => _withInstanceLock(
  repositoryRoot,
  () => _startIsolatedInstance(
    repositoryRoot: repositoryRoot,
    fixture: fixture,
    headless: headless,
    size: size,
    timeout: timeout,
  ),
);

/// Runs [body] holding `build/probe/instance.lock`: separate probe processes
/// (two `start`s, a `scenario` and a `start`) take turns on the instance
/// record instead of each starting an instance and overwriting the other's.
Future<T> _withInstanceLock<T>(
  String repositoryRoot,
  Future<T> Function() body,
) async {
  final file = File(p.join(repositoryRoot, 'build', 'probe', 'instance.lock'))
    ..parent.createSync(recursive: true);
  final lock = file.openSync(mode: FileMode.append);
  try {
    await lock.lock(FileLock.blockingExclusive);
    return await body();
  } finally {
    // Closing releases the lock. Never nested: a second open and close of
    // the same file in this process would release it early (POSIX locks).
    lock.closeSync();
  }
}

Future<IsolatedInstance> _startIsolatedInstance({
  required String repositoryRoot,
  required String fixture,
  required bool headless,
  required ({int width, int height}) size,
  required Duration timeout,
}) async {
  if (runningIsolatedInstance(repositoryRoot) case final running?) {
    throw ProbeError(
      'An isolated instance already runs (pid ${running.pid}, ${running.url}); '
      'stop it first.',
    );
  }
  // A record left by an instance that died: what it left (its display, its
  // bus, its directory) goes first.
  if (instanceFile(repositoryRoot).existsSync()) {
    await _stopIsolatedInstance(repositoryRoot);
  }
  final binary = findVeshellBinary(repositoryRoot);
  if (binary == null) {
    throw ProbeError('No debug build of Veshell: run `cargo build` first.');
  }
  final fixtureShare = p.join(
    repositoryRoot,
    'extra',
    'probe',
    'fixtures',
    fixture,
    'share',
  );
  if (!Directory(p.join(fixtureShare, 'applications')).existsSync()) {
    throw ProbeError(
      'No fixture "$fixture" (extra/probe/fixtures/$fixture/share/applications)',
    );
  }

  final root = Directory.systemTemp.createTempSync('veshell-probe-').path;
  final log = p.join(root, 'veshell.log');
  final owned = _OwnedProcesses(root);
  try {
    prepareIsolatedRoot(root);
    var environment = isolatedEnvironment(
      base: Platform.environment,
      root: root,
      fixtureShare: fixtureShare,
    );
    owned.bus = await startPrivateBus(root);
    if (headless) {
      final host = await startHeadlessHost(root: root, size: size);
      owned.host = host.pid;
      environment = {...environment, 'WAYLAND_DISPLAY': host.socket}
        ..remove('DISPLAY');
    }
    final before = await listeningProbePorts();
    final process = await Process.start(
      '/bin/sh',
      ['-c', r'exec "$0" > "$1" 2>&1', binary, log],
      workingDirectory: repositoryRoot,
      environment: environment,
      includeParentEnvironment: false,
      mode: ProcessStartMode.detached,
    );
    owned.veshell = process.pid;

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!isOwnProcess(
        process.pid,
        veshellProcessName,
        marker: p.basename(root),
      )) {
        throw ProbeError('The instance exited while starting:\n${_tail(log)}');
      }
      for (final port in (await listeningProbePorts()).difference(before)) {
        final url = Uri.parse('http://127.0.0.1:$port/');
        final ProbeConnection connection;
        try {
          connection = await ProbeConnection.open(url);
        } on ProbeError {
          continue; // Not serving the probe yet.
        }
        String? probeSocket;
        try {
          final info = await connection.call('info');
          probeSocket = (info as Map?)?['probeSocket'] as String?;
        } on ProbeError {
          // An embedder without the control socket.
        } finally {
          await connection.close();
        }
        owned.probeSocket = probeSocket;
        final instance = IsolatedInstance(
          pid: process.pid,
          url: url,
          root: root,
          fixture: fixture,
          log: log,
          hostPid: owned.host,
          busPid: owned.bus,
          probeSocket: probeSocket,
          size: headless ? size : null,
        );
        instanceFile(repositoryRoot)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(instance.toJson()),
          );
        return instance;
      }
    }
    throw ProbeError(
      'The instance did not serve the probe within $timeout:\n${_tail(log)}',
    );
  } on Object {
    await owned.cleanUp();
    rethrow;
  }
}

/// Stops the isolated instance (and its display and bus) and deletes its
/// directory and control socket. Only processes still running what the
/// probe started are signalled: a recorded PID may have been reused.
Future<Map<String, Object?>> stopIsolatedInstance(String repositoryRoot) =>
    _withInstanceLock(
      repositoryRoot,
      () => _stopIsolatedInstance(repositoryRoot),
    );

Future<Map<String, Object?>> _stopIsolatedInstance(
  String repositoryRoot,
) async {
  final file = instanceFile(repositoryRoot);
  if (!file.existsSync()) {
    return {'stopped': false, 'reason': 'No isolated instance recorded'};
  }
  final IsolatedInstance instance;
  try {
    instance = IsolatedInstance.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
    );
  } on Object {
    file.deleteSync();
    return {'stopped': false, 'reason': 'An unreadable record, removed'};
  }
  final owned = _OwnedProcesses(instance.root)
    ..veshell = instance.pid
    ..host = instance.hostPid
    ..bus = instance.busPid
    ..probeSocket = instance.probeSocket;
  await owned.cleanUp();
  file.deleteSync();
  return {'stopped': true, 'pid': instance.pid};
}

/// The process name of the Veshell binary.
const veshellProcessName = 'veshell';

/// Whether [pid] runs a program named [name] (its command line's first
/// word ends with it): a PID the probe recorded can be reused by an
/// unrelated process once its own exits.
bool isOwnProcess(int pid, String name, {String? marker}) {
  try {
    final command = File('/proc/$pid/cmdline').readAsStringSync();
    final program = command.split('\u0000').first;
    if (p.basename(program) != name) {
      return false;
    }
    // The program name alone matches the developer's own veshell or weston
    // too: the instance's processes also carry its directory's unique name,
    // on their command line (weston's socket, the bus address) or in their
    // environment (veshell's VESHELL_CONFIG_DIR).
    if (marker == null || command.contains(marker)) {
      return true;
    }
    return File('/proc/$pid/environ').readAsStringSync().contains(marker);
  } on FileSystemException {
    return false;
  }
}

/// What an isolated instance owns, to clean up on stop or on a failed
/// start: its processes, its directory and its control socket.
class _OwnedProcesses {
  _OwnedProcesses(this.root);

  final String root;
  int? veshell;
  int? host;
  int? bus;
  String? probeSocket;

  Future<void> cleanUp() async {
    await _end(veshell, veshellProcessName);
    await _end(host, 'weston');
    await _end(bus, 'dbus-daemon');
    // The embedder's control socket (it does not remove it on exit).
    final socket = probeSocket;
    if (socket != null && p.basename(socket).startsWith('veshell-probe-')) {
      try {
        File(socket).deleteSync();
      } on FileSystemException {
        // Already gone.
      }
    }
    if (p.basename(root).startsWith('veshell-probe-') &&
        Directory(root).existsSync()) {
      Directory(root).deleteSync(recursive: true);
    }
  }

  Future<void> _end(int? pid, String name) async {
    bool alive() =>
        pid != null && isOwnProcess(pid, name, marker: p.basename(root));
    if (!alive()) {
      return;
    }
    Process.killPid(pid!);
    for (var waited = 0; waited < 50 && alive(); waited++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (alive()) {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
  }
}

/// Starts a private session bus for an isolated instance (see
/// [isolatedEnvironment]); returns its process.
Future<int> startPrivateBus(String root) async {
  final socket = p.join(root, 'bus');
  final Process process;
  try {
    process = await Process.start('dbus-daemon', [
      '--session',
      '--nofork',
      '--nopidfile',
      '--address=unix:path=$socket',
    ], mode: ProcessStartMode.detached);
  } on ProcessException catch (error) {
    throw ProbeError(
      'Cannot start a private session bus (dbus-daemon): $error',
    );
  }
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (File(socket).existsSync()) {
      return process.pid;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (isOwnProcess(process.pid, 'dbus-daemon', marker: p.basename(root))) {
    Process.killPid(process.pid);
  }
  throw ProbeError('The private session bus did not start');
}

/// Starts a headless Weston of [size] for an isolated instance to nest in
/// (GL renderer, for the instance's own GL; kiosk shell, so its window
/// fills the display); returns its process and Wayland socket name.
Future<({int pid, String socket})> startHeadlessHost({
  required String root,
  required ({int width, int height}) size,
}) async {
  final runtime = Platform.environment['XDG_RUNTIME_DIR'];
  if (runtime == null) {
    throw ProbeError('No XDG_RUNTIME_DIR for the headless display');
  }
  final socket = 'veshell-probe-host-${p.basename(root)}';
  final log = p.join(root, 'weston.log');
  final Process process;
  try {
    process = await Process.start(
      '/bin/sh',
      [
        '-c',
        r'exec weston --backend=headless --renderer=gl --shell=kiosk-shell.so '
            r'--no-config --width="$1" --height="$2" --socket="$3" > "$0" 2>&1',
        log,
        '${size.width}',
        '${size.height}',
        socket,
      ],
      environment: {...Platform.environment}
        ..remove('DISPLAY')
        ..remove('WAYLAND_DISPLAY'),
      includeParentEnvironment: false,
      mode: ProcessStartMode.detached,
    );
  } on ProcessException catch (error) {
    throw ProbeError('Cannot start the headless display: $error');
  }
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    if (File(p.join(runtime, socket)).existsSync()) {
      return (pid: process.pid, socket: socket);
    }
    if (!Directory('/proc/${process.pid}').existsSync()) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  Process.killPid(process.pid);
  throw ProbeError(
    'The headless display (weston) did not start; is weston installed? Use '
    '--windowed to nest in your session instead.\n${_tail(log)}',
  );
}

/// The ports among those scanned something listens on.
Future<Set<int>> listeningProbePorts() async {
  final ports = [
    for (
      var port = firstVmServicePort;
      port < firstVmServicePort + scannedPorts;
      port++
    )
      port,
  ];
  final open = await Future.wait(ports.map(isListening));
  return {
    for (var index = 0; index < ports.length; index++)
      if (open[index]) ports[index],
  };
}

String _tail(String log) {
  final file = File(log);
  if (!file.existsSync()) {
    return '(no log)';
  }
  final lines = file.readAsLinesSync();
  return lines.skip(lines.length > 30 ? lines.length - 30 : 0).join('\n');
}

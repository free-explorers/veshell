import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

/// The application a systemd unit under the user manager's `app.slice` is
/// expected to belong to.
///
/// Launchers that move an application out of the cgroup it was started in
/// put it in a transient scope, named by the systemd convention for desktop
/// applications:
///
/// ```text
/// app[-<launcher>]-<application id>-<random>.scope
/// ```
///
/// Seen in practice: `app-steam-app1422450-44276.scope` (a Steam game), and
/// `app-org.chromium.Chromium-2345.scope` or `app-code-oss-3456.scope`
/// (Chromium and Electron move themselves). `flatpak run` names its scopes
/// `app-flatpak-<app id>-<pid>.scope`.
///
/// The convention escapes the id the systemd way (`-` as `\x2d`), which
/// Chromium does not follow (`code-oss` keeps its dash), so both spellings
/// are accepted. The id is known in advance (it is the tile's), so a name is
/// only ever checked against it, never parsed into one: the dashes the
/// convention uses as separators cannot be told apart from an id's own.
///
/// Only the launchers in [knownLaunchers] may precede the id: accepting any
/// word would let a short id match the tail of a longer one (`oss` in
/// `app-code-oss-3456.scope`).
///
/// D-Bus activation (an entry with `DBusActivatable=true`) starts the
/// application as a service named after its bus name, which for such an
/// entry is its desktop id, inside a slice of that name:
///
/// ```text
/// app-dbus\x2d:1.31\x2d<bus name>.slice/dbus-:1.31-<bus name>@0.service
/// ```
///
/// The slice outlives the service (an empty one stays behind), so the
/// service is what starts and ends with the application.
class ScopeIdentity {
  const ScopeIdentity(this.applicationId, {this.launcher});

  /// The scope Steam starts game [appId] in: Steam names it `app<id>`, under
  /// the launcher `steam`.
  const ScopeIdentity.steamGame(String appId)
    : applicationId = 'app$appId',
      launcher = 'steam';

  /// The application id the scope names (a desktop id, or Steam's
  /// `app<id>`).
  final String applicationId;

  /// The launcher the scope must name, or null for any of [knownLaunchers]
  /// (or none). A launcher also rules out D-Bus activation.
  final String? launcher;

  /// The launchers seen putting an application in a scope of its own.
  static const knownLaunchers = {'flatpak', 'steam'};

  static final _randomSuffix = RegExp(r'-[A-Za-z0-9]+$');
  static final _dbusSlice = RegExp(r'^app-dbus\\x2d:[0-9.]+\\x2d(.+)\.slice$');
  static final _dbusService = RegExp(r'^dbus-:[0-9.]+-(.+)@[0-9]+\.service$');

  Set<String> get _spellings => {applicationId, systemdEscape(applicationId)};

  /// Whether [scopeName] is a scope of this application.
  bool matches(String scopeName) {
    if (applicationId.isEmpty ||
        !scopeName.startsWith('app-') ||
        !scopeName.endsWith('.scope')) {
      return false;
    }
    final body = scopeName.substring(4, scopeName.length - '.scope'.length);
    final suffix = _randomSuffix.firstMatch(body);
    if (suffix == null) {
      return false;
    }
    final named = body.substring(0, suffix.start);
    for (final id in _spellings) {
      if (named == id) {
        if (launcher == null) return true;
        continue;
      }
      if (!named.endsWith('-$id')) {
        continue;
      }
      final word = named.substring(0, named.length - id.length - 1);
      if (launcher != null ? word == launcher : knownLaunchers.contains(word)) {
        return true;
      }
    }
    return false;
  }

  /// Whether [sliceName] is the D-Bus activation slice of this application.
  bool matchesDBusSlice(String sliceName) {
    if (applicationId.isEmpty || launcher != null) return false;
    final busName = _dbusSlice.firstMatch(sliceName)?.group(1);
    return busName != null && _spellings.contains(busName);
  }

  /// Whether [serviceName] is the D-Bus activated service of this
  /// application.
  bool matchesDBusService(String serviceName) {
    if (applicationId.isEmpty || launcher != null) return false;
    final busName = _dbusService.firstMatch(serviceName)?.group(1);
    return busName != null && _spellings.contains(busName);
  }

  @override
  String toString() =>
      'ScopeIdentity(${launcher == null ? '' : '$launcher/'}$applicationId)';
}

/// [value] escaped as in a systemd unit name: every byte other than an ASCII
/// letter, digit, `:`, `_` or a non-leading `.` becomes `\xNN`.
String systemdEscape(String value) {
  final escaped = StringBuffer();
  final bytes = utf8.encode(value);
  for (var i = 0; i < bytes.length; i++) {
    final byte = bytes[i];
    final keep =
        (byte >= 0x30 && byte <= 0x39) ||
        (byte >= 0x41 && byte <= 0x5a) ||
        (byte >= 0x61 && byte <= 0x7a) ||
        byte == 0x3a ||
        byte == 0x5f ||
        (byte == 0x2e && i > 0);
    if (keep) {
      escaped.writeCharCode(byte);
    } else {
      escaped.write('\\x${byte.toRadixString(16).padLeft(2, '0')}');
    }
  }
  return escaped.toString();
}

/// Follows a launch that another process carries out, through the systemd
/// unit the application ends up in (see [ScopeIdentity]).
///
/// `steam steam://rungameid/<id>` hands the launch to the running client and
/// exits, `flatpak run` and Chromium move the application into a scope of its
/// own, D-Bus activation starts it as a service: either way the tile's own
/// launch cgroup empties while the application is still to come, or still
/// running. Its unit is what remains observable: the directory appears under
/// `app.slice` (or the application's D-Bus slice) when the application
/// starts, and systemd removes it once the application's last process is
/// gone.
///
/// Only a unit created after tracking started counts, so an application
/// that is already running is not mistaken for this launch. Reports
/// [onStarted] once, then [onEnded] once when that unit is removed.
class LaunchScopeTracker {
  LaunchScopeTracker({
    required this.slicePath,
    required this.identity,
    required this.onStarted,
    required this.onEnded,
    Stream<FileSystemEvent> Function(String path) watch = _watchDirectory,
    Iterable<String> Function(String path) list = _listDirectory,
  }) : _watch = watch {
    if (!_listen(slicePath, _onSliceEvent, essential: true)) {
      return;
    }
    // A D-Bus slice left over from an earlier activation gets the service of
    // the next one without being created again.
    for (final name in list(slicePath)) {
      if (identity.matchesDBusSlice(name)) {
        _watchDBusSlice(name);
      }
    }
  }

  /// Watches [slice] (the user manager's `app.slice` cgroup directory).
  factory LaunchScopeTracker.watch({
    required Directory slice,
    required ScopeIdentity identity,
    required void Function(String unit) onStarted,
    required void Function(String unit) onEnded,
  }) => LaunchScopeTracker(
    slicePath: slice.path,
    identity: identity,
    onStarted: onStarted,
    onEnded: onEnded,
  );

  final String slicePath;
  final ScopeIdentity identity;
  final void Function(String unit) onStarted;
  final void Function(String unit) onEnded;
  final Stream<FileSystemEvent> Function(String path) _watch;

  final _subscriptions = <StreamSubscription<FileSystemEvent>>[];
  final _watchedDBusSlices = <String>{};

  /// The unit this launch started in, relative to the slice, once it
  /// appeared: a scope, or `<D-Bus slice>/<service>`.
  String? scope;

  bool _ended = false;

  /// Subscribes to [directory]; tracking is an improvement over waiting,
  /// never a requirement for the launch, so a directory that cannot be
  /// watched is skipped, and losing the [essential] one ends tracking.
  bool _listen(
    String directory,
    void Function(FileSystemEvent event) onEvent, {
    bool essential = false,
  }) {
    try {
      _subscriptions.add(
        _watch(directory).listen(
          onEvent,
          onError: (Object _) {
            if (essential) cancel();
          },
        ),
      );
      return true;
    } on FileSystemException {
      if (essential) cancel();
      return false;
    }
  }

  void _onSliceEvent(FileSystemEvent event) {
    if (_ended) return;
    final name = path.basename(event.path);
    if (scope == null && event is FileSystemCreateEvent) {
      if (identity.matches(name)) {
        _start(name);
      } else if (identity.matchesDBusSlice(name)) {
        _watchDBusSlice(name);
      }
      return;
    }
    final current = scope;
    if (current != null &&
        event is FileSystemDeleteEvent &&
        (name == current || current.startsWith('$name/'))) {
      _end(current);
    }
  }

  void _watchDBusSlice(String sliceName) {
    if (!_watchedDBusSlices.add(sliceName)) return;
    _listen(path.join(slicePath, sliceName), (event) {
      if (_ended) return;
      final unit = '$sliceName/${path.basename(event.path)}';
      if (scope == null &&
          event is FileSystemCreateEvent &&
          identity.matchesDBusService(path.basename(event.path))) {
        _start(unit);
      } else if (event is FileSystemDeleteEvent && unit == scope) {
        _end(unit);
      }
    });
  }

  void _start(String unit) {
    scope = unit;
    onStarted(unit);
  }

  void _end(String unit) {
    cancel();
    onEnded(unit);
  }

  void cancel() {
    _ended = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }
}

Stream<FileSystemEvent> _watchDirectory(String directory) =>
    Directory(directory).watch();

Iterable<String> _listDirectory(String directory) {
  try {
    return Directory(directory).listSync().whereType<Directory>().map(
      (entry) => path.basename(entry.path),
    );
  } on FileSystemException {
    return const [];
  }
}

/// The user manager's `app.slice` cgroup directory, where it starts the
/// transient scopes of launched applications, or null when there is none
/// (no cgroup v2 hierarchy, no systemd user manager).
Directory? userAppSliceDirectory({
  String cgroupRoot = '/sys/fs/cgroup',
  String? procSelfStatus,
}) {
  final String status;
  try {
    status = procSelfStatus ?? File('/proc/self/status').readAsStringSync();
  } on FileSystemException {
    return null;
  }
  final uidLine = status
      .split('\n')
      .where((line) => line.startsWith('Uid:'))
      .firstOrNull;
  final uid = uidLine?.substring(4).trim().split(RegExp(r'\s+')).first;
  if (uid == null || int.tryParse(uid) == null) {
    return null;
  }
  final directory = Directory(
    path.join(
      cgroupRoot,
      'user.slice',
      'user-$uid.slice',
      'user@$uid.service',
      'app.slice',
    ),
  );
  return directory.existsSync() ? directory : null;
}

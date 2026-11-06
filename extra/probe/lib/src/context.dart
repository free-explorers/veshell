import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:veshell_probe/src/connection.dart';
import 'package:veshell_probe/src/isolated.dart';
import 'package:veshell_probe/src/probe.dart';

/// The Veshell repository the probe belongs to: found from the probe's own
/// location, else from the working directory upwards.
String? findRepositoryRoot() {
  bool isRoot(String directory) =>
      File(p.join(directory, 'src', 'shell', 'pubspec.yaml')).existsSync() &&
      File(p.join(directory, 'Cargo.toml')).existsSync();
  String? above(String start) {
    var directory = p.normalize(p.absolute(start));
    while (true) {
      if (isRoot(directory)) {
        return directory;
      }
      final parent = p.dirname(directory);
      if (parent == directory) {
        return null;
      }
      directory = parent;
    }
  }

  // Where the program lives: bin/veshell_probe.dart under `dart run`, the
  // compiled binary in extra/probe/.dart_tool otherwise; else where it runs.
  final script = Platform.script;
  if (script.scheme == 'file') {
    if (above(p.dirname(script.toFilePath())) case final root?) {
      return root;
    }
  }
  return above(Directory.current.path);
}

/// The `act` parameters for an action: `{tap: {…}}`, `{key: chord}` or
/// `{type: text}` (with an optional `clear`).
Map<String, Object?> actionParams(Map<String, Object?> action) {
  if (action['tap'] case final Map<String, Object?> tap) {
    return {'action': 'tap', ...tap};
  }
  if (action['key'] case final String chord) {
    return {'action': 'key', 'key': chord};
  }
  if (action['type'] case final String text) {
    return {'action': 'type', 'text': text, 'clear': action['clear'] == true};
  }
  throw ProbeError(
    'An action is {"tap": {...}}, {"key": "Enter"} or {"type": "text"}',
  );
}

/// Keeps a [Probe] for the instance at [url] (or the discovered one), and
/// opens it again when it went away.
class ProbeSession {
  ProbeSession({this.url, String? repositoryRoot, this.allowInput = false})
    : repositoryRoot = repositoryRoot ?? findRepositoryRoot();

  final Uri? url;
  final String? repositoryRoot;

  /// Whether input may go into an instance the probe did not start (the
  /// developer's own): taps and keys there act on a real session.
  final bool allowInput;

  /// The probe of the instance at [url], if input may go into it: the
  /// isolated instance always, any other only with [allowInput] or
  /// [allowed] (a call's own `allowInput`).
  Future<Probe> probeForInput({Uri? url, bool allowed = false}) async {
    final probe = await this.probe(url: url);
    final isolated = runningIsolatedInstance(repositoryRoot);
    if (allowInput ||
        allowed ||
        (isolated != null && isolated.url == probe.connection.httpUri)) {
      return probe;
    }
    throw ProbeError(
      'Refusing to send input to ${probe.connection.httpUri}: it is not the '
      "probe's isolated instance, so taps and keys would act on a real "
      'session. Start an isolated one (`start`), or allow it explicitly '
      '(--allow-input, or allowInput: true).',
    );
  }

  Probe? _probe;

  ProbeOutput get output => ProbeOutput.forRepository(repositoryRoot);

  /// The probe of the instance at [url], else the session's, else the
  /// running isolated instance, else the only instance found.
  Future<Probe> probe({Uri? url}) async {
    final wanted =
        url ?? this.url ?? runningIsolatedInstance(repositoryRoot)?.url;
    final current = _probe;
    if (current != null &&
        (wanted == null || wanted == current.connection.httpUri)) {
      // The VM outlives a hot restart, which replaces the isolate: check that
      // the isolate in use is still there and still serves the probe.
      try {
        final isolate = await current.connection.service
            .getIsolate(current.connection.isolateId)
            .timeout(const Duration(seconds: 5));
        if (isolate.extensionRPCs?.contains('ext.veshell.views') ?? false) {
          return current;
        }
      } on Object {
        // Gone: connect again below.
      }
      _probe = null;
    }
    await current?.connection.close().catchError((_) {});
    final connection = await ProbeConnection.discover(
      explicit: wanted,
      repositoryRoot: repositoryRoot,
    );
    return _probe = Probe(connection, output);
  }

  /// Resumes the animation clock of the instance in use, if it has one and
  /// it is reachable; never fails.
  Future<void> resumeClock() async {
    final current = _probe;
    if (current == null) {
      return;
    }
    try {
      Future<void> resume() async {
        if (await current.hasClock()) {
          await current.clock('resume');
        }
      }

      await resume().timeout(const Duration(seconds: 2));
    } on Object {
      // The instance is gone or was restarted: nothing to resume.
    }
  }

  Future<void> close() async {
    await _probe?.connection.close();
    _probe = null;
  }
}

import 'dart:async';
import 'dart:io';

import 'package:shell/shared/util/logger.dart';

/// Latest content requested per path, pending a debounced flush.
final Map<String, String> _latestFileContents = {};

/// Debounce timer per path; present while a flush is scheduled.
final Map<String, Timer> _debounceTimers = {};

/// In-flight flush per path, so consecutive flushes never overlap.
final Map<String, Future<void>> _writeChains = {};

/// Writes [content] to [path] atomically (temp file + rename), debounced per
/// path. Concurrent calls for the same path coalesce into a single write.
Future<void> writeFileAtomically(String path, String content) async {
  if (_latestFileContents[path] == content) {
    return;
  }
  _latestFileContents[path] = content;
  if (_debounceTimers[path] != null) {
    return;
  }
  _debounceTimers[path] = Timer(const Duration(milliseconds: 100), () {
    _debounceTimers.remove(path);
    // Take the pending content synchronously, before any await: a concurrent
    // call either coalesces into this write or schedules a fresh timer, but
    // never leaves this snapshot null.
    final pending = _latestFileContents.remove(path);
    if (pending == null) {
      return;
    }
    _enqueueFlush(path, pending);
  });
}

/// Writes [content] to [path] immediately, bypassing the debounce cache.
///
/// For storage maintenance only (migration rewrites during startup), where no
/// other writer for the path can be active yet. Normal state writes should go
/// through [writeFileAtomically].
Future<void> writeFileAtomicallyNow(String path, String content) =>
    _flushTempFile(path, content);

/// Drops a pending debounced write for [path].
///
/// Used before deleting a key so a timer armed by the last state change cannot
/// recreate the file after the delete.
void discardPendingWrite(String path) {
  _debounceTimers.remove(path)?.cancel();
  _latestFileContents.remove(path);
}

/// Deletes [path] after any write already in flight for it.
///
/// A plain `File.delete` can race a flush that has left the debounce cache but
/// not yet renamed its temp file, which would recreate the state that was just
/// deleted. Chaining the deletion on the same per-path queue makes "delete"
/// final.
Future<void> deleteFileQueued(String path) {
  discardPendingWrite(path);
  return _enqueueOperation(path, () async {
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final tempFile = File('$path.tmp');
    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }
  });
}

/// Flushes every pending debounced write and waits for in-flight writes.
///
/// Promotes each pending snapshot into its per-path write chain (the same
/// chain used by the debounce timer), then waits for the chains to drain. New
/// writes that arrive while flushing are included in the next pass, so the
/// call is bounded by [timeout] rather than by writer activity. Persistence is
/// best-effort during shutdown: a timeout is logged, never thrown.
Future<void> flushPendingWrites({
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);

  // Promote every pending snapshot synchronously, before the first await, so a
  // write that is already in the cache cannot be missed.
  for (final path in _latestFileContents.keys.toList()) {
    _debounceTimers.remove(path)?.cancel();
    final pending = _latestFileContents.remove(path);
    if (pending != null) {
      _enqueueFlush(path, pending);
    }
  }

  while (_writeChains.isNotEmpty) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      persistenceLog.warning(
        'Persistence flush timed out with ${_writeChains.length} write(s) '
        'still in flight: ${_writeChains.keys.join(', ')}',
      );
      return;
    }

    try {
      await Future.wait(_writeChains.values.toList()).timeout(remaining);
    } on TimeoutException {
      persistenceLog.warning(
        'Persistence flush timed out with ${_writeChains.length} write(s) '
        'still in flight: ${_writeChains.keys.join(', ')}',
      );
      return;
    }

    // Chain cleanup is scheduled from `whenComplete`; let it run before
    // deciding whether the storage is idle.
    await Future<void>.delayed(Duration.zero);

    if (_writeChains.isEmpty) {
      return;
    }
  }
}

/// Appends a flush of [pending] to [path]'s write chain.
///
/// The temp file name is derived from the path, so flushes for the same path
/// must not overlap: a slow write still running when the debounce fires again
/// would otherwise delete or rename the temp file out from under the next one.
void _enqueueFlush(String path, String pending) {
  unawaited(_enqueueOperation(path, () => _flushTempFile(path, pending)));
}

/// Appends [operation] to [path]'s write chain and returns its completion.
///
/// Errors are swallowed so one failed flush cannot break later writes, which
/// also means the returned future completes after the operation has run but
/// does not report I/O failure.
Future<void> _enqueueOperation(String path, Future<void> Function() operation) {
  final previous = _writeChains[path] ?? Future<void>.value();
  final next = previous
      .then((_) => operation())
      // Persistence is best-effort: a transient I/O failure must not surface as
      // an unhandled async error, and must not break the chain for later
      // writes. The pending content was already dropped from the cache, so the
      // next call re-queues it.
      .catchError((Object _) {});
  _writeChains[path] = next;
  unawaited(
    next.whenComplete(() {
      if (identical(_writeChains[path], next)) {
        unawaited(_writeChains.remove(path));
      }
    }),
  );
  return next;
}

/// Writes [content] to [path] through a `$path.tmp` file and an atomic rename.
///
/// The temp file is narrowed to owner-only before the rename, so a newly
/// written state file is never readable by other local users and the rename
/// cannot expose the content with wider permissions.
Future<void> _flushTempFile(String path, String content) async {
  final tempFile = File('$path.tmp');
  await tempFile.create(recursive: true);
  await tempFile.writeAsString(content, flush: true);
  await _setPrivateFilePermissions(tempFile.path);
  await tempFile.rename(path);
}

Future<void> _setPrivateFilePermissions(String path) =>
    setPathPermissions(path, '600');

/// Applies [mode] (an octal chmod mode such as `700`) to [path].
///
/// Failures are logged and swallowed: persistence must keep working on a file
/// system that does not support permissions, even though that is a privacy
/// regression worth reporting.
Future<void> setPathPermissions(String path, String mode) async {
  try {
    final result = await Process.run('chmod', [mode, path]);
    if (result.exitCode != 0) {
      persistenceLog.warning(
        'Could not set permissions on $path: ${result.stderr}',
      );
    }
  } on ProcessException catch (error) {
    persistenceLog.warning(
      'Could not set permissions on $path: ${error.message}',
    );
  }
}

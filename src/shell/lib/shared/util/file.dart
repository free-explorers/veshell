import 'dart:async';
import 'dart:io';

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

/// Appends a flush of [pending] to [path]'s write chain.
///
/// The temp file name is derived from the path, so flushes for the same path
/// must not overlap: a slow write still running when the debounce fires again
/// would otherwise delete or rename the temp file out from under the next one.
void _enqueueFlush(String path, String pending) {
  final previous = _writeChains[path] ?? Future<void>.value();
  final next = previous
      .then((_) => _flushTempFile(path, pending))
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
}

/// Writes [content] to [path] through a `$path.tmp` file and an atomic rename.
Future<void> _flushTempFile(String path, String content) async {
  final tempFile = File('$path.tmp');
  await tempFile.create(recursive: true);
  await tempFile.writeAsString(content);
  await tempFile.rename(path);
}

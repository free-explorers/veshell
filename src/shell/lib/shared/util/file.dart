import 'dart:async';
import 'dart:io';

final Map<String, String> _latestFileContents = {};
final Map<String, Timer> _debounceTimers = {};

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
  _debounceTimers[path] = Timer(const Duration(milliseconds: 100), () async {
    _debounceTimers.remove(path);
    // Take the pending content synchronously, before any await: a concurrent
    // call either coalesces into this write or schedules a fresh timer, but
    // never leaves this snapshot null.
    final pending = _latestFileContents.remove(path);
    if (pending == null) {
      return;
    }
    final tempFile = File('$path.tmp');
    if (tempFile.existsSync()) {
      await tempFile.delete();
    }
    await tempFile.create(recursive: true);
    await tempFile.writeAsString(pending);
    await tempFile.rename(path);
  });
}

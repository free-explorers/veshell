import 'dart:async';
import 'dart:io';

final Map<String, String> _latestFileContents = {};
final Map<String, Timer> _debounceTimers = {};

Future<void> writeFileAtomically(
  String path,
  String content) async {
  // Create a temp file path
	if (_latestFileContents[path] == content) {
		return;
	}
	_latestFileContents[path] = content;
	if (_debounceTimers[path] != null) {
		return;
	}
	_debounceTimers[path] = Timer(const Duration(milliseconds: 100), () async {
		_debounceTimers.remove(path);
		final tempFile = File('${path}.tmp');

  if (tempFile.existsSync()) {
   await tempFile.delete();
  }
 	await tempFile.create(recursive: true);
  await tempFile.writeAsString(_latestFileContents[path]!);
	_latestFileContents.remove(path);
	await tempFile.rename(path);
	});
}
  

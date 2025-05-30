import 'dart:io';

Future<void> writeFileAtomically(String path, String content) async {
  // Create a temp file path
  final tempFile = File('$path.tmp');

  // Try to create the temp file - this acts as our mutex
  try {
    // Create temp file - will throw if it already exists
    await tempFile.create(exclusive: true);

    // Now we have the lock, perform the write operation
    await tempFile.writeAsString(content);
    await tempFile.rename(path);
  } on FileSystemException catch (_) {
    // If we couldn't create the lock file, wait and retry
    await Future.delayed(const Duration(milliseconds: 100));
    return writeFileAtomically(path, content);
  }
}

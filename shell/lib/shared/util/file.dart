import 'dart:io';

Future<void> writeFileAtomically(String path, String content) async {
  final tempFile = File('$path.tmp');
  if (!tempFile.existsSync()) {
    await tempFile.create(recursive: true);
  }
  await tempFile.writeAsString(content);
  await tempFile.rename(path);
}

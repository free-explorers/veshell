import 'dart:async';
import 'dart:io';

Future<void> writeFileAtomically(
  String path,
  String content, {
  bool retry = true,
}) async {
  // Create a temp file path
  final timestampSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final tempFile = File('${path}_$timestampSeconds.tmp');

  if (!tempFile.existsSync()) {
    await tempFile.create(recursive: true);
    unawaited(
      Future<void>.delayed(const Duration(seconds: 1)).then((_) async {
        await tempFile.rename(path);
      }),
    );
  }

  await tempFile.writeAsString(content);
}

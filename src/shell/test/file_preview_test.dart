import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_preview/model/file_preview.dart';
import 'package:shell/file_preview/provider/file_preview.dart';

void main() {
  late Directory tempDirectory;
  late ProviderContainer container;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('file_preview_test');
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tempDirectory.delete(recursive: true);
  });

  Future<FilePreview> previewOf(String name) {
    final file = File('${tempDirectory.path}/$name');
    return container.read(filePreviewProvider(DirectoryPath(file.path)).future);
  }

  test('previews a text file', () async {
    await File('${tempDirectory.path}/notes.txt').writeAsString('hello world');
    final preview = await previewOf('notes.txt');
    expect(preview, isA<TextFilePreview>());
    expect((preview as TextFilePreview).content, 'hello world');
    expect(preview.isTruncated, isFalse);
  });

  test('returns an image preview for a known image extension', () async {
    await File(
      '${tempDirectory.path}/photo.png',
    ).writeAsBytes([0x89, 0x50, 0x4e, 0x47]);
    expect(await previewOf('photo.png'), isA<ImageFilePreview>());
  });

  test('returns an svg preview for svg', () async {
    await File('${tempDirectory.path}/icon.svg').writeAsString('<svg></svg>');
    expect(await previewOf('icon.svg'), isA<SvgFilePreview>());
  });

  test('sniffs an extensionless text file', () async {
    await File('${tempDirectory.path}/README').writeAsString('readme');
    expect(await previewOf('README'), isA<TextFilePreview>());
  });

  test('returns a binary preview for a file with NUL bytes', () async {
    await File('${tempDirectory.path}/blob').writeAsBytes([0, 1, 2, 3]);
    final preview = await previewOf('blob');
    expect(preview, isA<BinaryFilePreview>());
    expect((preview as BinaryFilePreview).size, 4);
  });

  test('summarises a directory', () async {
    await Directory('${tempDirectory.path}/sub').create();
    await File('${tempDirectory.path}/sub/a.txt').writeAsString('a');
    final preview = await container.read(
      filePreviewProvider(DirectoryPath('${tempDirectory.path}/sub')).future,
    );
    expect(preview, isA<DirectoryFilePreview>());
    expect((preview as DirectoryFilePreview).entryCount, 1);
  });

  test('errors on a missing path', () async {
    final preview = await container.read(
      filePreviewProvider(
        DirectoryPath('${tempDirectory.path}/missing'),
      ).future,
    );
    expect(preview, isA<ErrorFilePreview>());
  });
}

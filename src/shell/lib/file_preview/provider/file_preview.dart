import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_preview/model/file_preview.dart';

part 'file_preview.g.dart';

/// Largest prefix read for a text preview.
const int textPreviewByteLimit = 256 * 1024;

/// Prefix read to decide whether a file is text or binary.
const int _sniffByteLimit = 8 * 1024;

/// Bytes shown in a binary hex dump.
const _hexDumpByteLimit = 512;

/// Entries counted for a directory summary before it is reported as capped.
const _directoryCountLimit = 1000;

const _rasterImageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'ico',
  'wbmp',
};

const _svgExtensions = {'svg'};

/// Builds the preview for [path]. The result is cached by the provider while
/// the selection stays on this path.
@riverpod
Future<FilePreview> filePreview(Ref ref, DirectoryPath path) async {
  final file = File(path.path);
  final FileStat stat;
  try {
    // Asynchronous on purpose: stat'ing synchronously would block the frame.
    // ignore: avoid_slow_async_io
    stat = await file.stat();
  } on FileSystemException catch (error) {
    return FilePreview.error(message: error.message);
  }
  if (stat.type == FileSystemEntityType.notFound) {
    return FilePreview.error(message: 'No such file: ${path.path}');
  }

  final name = p.basename(path.path);
  if (stat.type == FileSystemEntityType.directory) {
    final entryCount = await Directory(
      path.path,
    ).list().take(_directoryCountLimit).length;
    return FilePreview.directory(name: name, entryCount: entryCount);
  }

  final extension = _extensionOf(name);
  if (_svgExtensions.contains(extension)) {
    return FilePreview.svg(path: path.path);
  }
  if (_rasterImageExtensions.contains(extension)) {
    return FilePreview.image(path: path.path);
  }

  try {
    return await _readTextOrBinary(
      file,
      name: name,
      size: stat.size,
      modified: stat.modified,
    );
  } on FileSystemException catch (error) {
    return FilePreview.error(message: error.message);
  }
}

/// Reads a prefix of [file] and returns a text or binary preview. Files with an
/// unknown extension are sniffed, so an extensionless `README` still previews.
Future<FilePreview> _readTextOrBinary(
  File file, {
  required String name,
  required int size,
  required DateTime modified,
}) async {
  final sniff = await _readPrefix(file, _sniffByteLimit);
  if (sniff.isEmpty) {
    return FilePreview.metadata(name: name, size: size, modified: modified);
  }
  if (_looksBinary(sniff)) {
    return FilePreview.binary(
      hexDump: _hexDump(sniff.take(_hexDumpByteLimit).toList()),
      size: size,
    );
  }
  final bytes = size > sniff.length
      ? await _readPrefix(file, textPreviewByteLimit)
      : sniff;
  return FilePreview.text(
    content: utf8.decode(bytes, allowMalformed: true),
    isTruncated: size > bytes.length,
  );
}

/// Reads at most [limit] bytes from the start of [file].
Future<List<int>> _readPrefix(File file, int limit) async {
  final bytes = <int>[];
  await file.openRead(0, limit).forEach(bytes.addAll);
  return bytes;
}

/// Whether [bytes] look like a non-text file (a NUL byte in the sample).
bool _looksBinary(List<int> bytes) {
  final sample = bytes.length > 512 ? bytes.sublist(0, 512) : bytes;
  return sample.contains(0);
}

/// Formats [bytes] as a 16-column hex dump.
String _hexDump(List<int> bytes) {
  final buffer = StringBuffer();
  for (var offset = 0; offset < bytes.length; offset += 16) {
    final end = offset + 16 <= bytes.length ? offset + 16 : bytes.length;
    final row = bytes.sublist(offset, end);
    buffer.writeln(
      row.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' '),
    );
  }
  return buffer.toString().trimRight();
}

/// The lower-case extension of [name], or an empty string.
String _extensionOf(String name) {
  final dotIndex = name.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == name.length - 1) {
    return '';
  }
  return name.substring(dotIndex + 1).toLowerCase();
}

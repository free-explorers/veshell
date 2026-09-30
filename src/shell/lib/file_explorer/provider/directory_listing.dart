import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';

part 'directory_listing.g.dart';

/// Lists one directory, once.
///
/// The provider is auto-disposed when the pane navigates away, so a slow
/// directory never delays the next one. Entries that cannot be stat'ed (a
/// broken symlink, a file removed mid-listing) are skipped rather than failing
/// the whole directory.
@riverpod
Future<List<FileEntry>> directoryListing(Ref ref, DirectoryPath path) async {
  final entityList = await Directory(path.path).list().toList();
  final entryList = <FileEntry>[];
  for (final entity in entityList) {
    final FileStat stat;
    try {
      // Asynchronous on purpose: stat'ing every entry synchronously would block
      // the shell's frame on large directories.
      // ignore: avoid_slow_async_io
      stat = await entity.stat();
    } on FileSystemException {
      continue;
    }
    final isDirectory = stat.type == FileSystemEntityType.directory;
    entryList.add(
      FileEntry(
        name: p.basename(entity.path),
        path: DirectoryPath(entity.path),
        isDirectory: isDirectory,
        size: isDirectory ? 0 : stat.size,
      ),
    );
  }
  return entryList;
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/file_explorer/model/directory_path.dart';

part 'directory_item_count.g.dart';

/// How many entries the folder at [path] holds, dotfiles counted only when
/// [includeHidden] is set, for the details line of a folder row.
///
/// Only rows on screen ask for it and it is disposed with them, so a large
/// listing never enumerates every subfolder. An unreadable folder fails, and
/// the row then shows no count.
@riverpod
Future<int> directoryItemCount(
  Ref ref,
  DirectoryPath path,
  bool includeHidden,
) async {
  var count = 0;
  await for (final entity in Directory(path.path).list()) {
    if (!includeHidden && p.basename(entity.path).startsWith('.')) {
      continue;
    }
    count++;
  }
  return count;
}

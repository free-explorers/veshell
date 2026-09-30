import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/file_explorer/model/directory_path.dart';

part 'file_entry.freezed.dart';

/// One row of the file explorer: a directory or a file in the listed folder.
@freezed
abstract class FileEntry with _$FileEntry {
  const factory FileEntry({
    required String name,
    required DirectoryPath path,
    required bool isDirectory,
    required int size,
  }) = _FileEntry;
}

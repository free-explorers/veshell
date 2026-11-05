import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_kind.dart';

part 'file_entry.freezed.dart';

/// One row of the file explorer: a directory or a file in the listed folder.
@freezed
abstract class FileEntry with _$FileEntry {
  const factory FileEntry({
    required String name,
    required DirectoryPath path,
    required bool isDirectory,
    required int size,

    /// Last modification time, or `null` when it is unknown.
    DateTime? modified,
  }) = _FileEntry;
  const FileEntry._();

  /// Dotfiles are hidden unless the explorer is set to show them.
  bool get isHidden => name.startsWith('.');

  /// The entry's broad type.
  FileKind get kind => isDirectory ? FileKind.folder : fileKindForName(name);
}

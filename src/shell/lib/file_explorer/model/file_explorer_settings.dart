import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_explorer_settings.freezed.dart';

/// The key the file explorer sorts its entries by.
///
/// The enum names are the values stored under `files.sortBy`.
enum FileSortKey {
  /// Natural, case-insensitive name order (`file2` before `file10`).
  name,

  /// Last modification time.
  modified,

  /// File size; folders, which have none, keep their name order.
  size,

  /// The broad file type, then the extension, then the name.
  type,
}

/// How the file explorer lists a directory, persisted under `files.*` and
/// shared by the overview's Files pane and the portal file chooser.
@freezed
abstract class FileExplorerSettings with _$FileExplorerSettings {
  const factory FileExplorerSettings({
    @Default(false) bool showHidden,
    @Default(FileSortKey.name) FileSortKey sortBy,
    @Default(false) bool sortDescending,
    @Default(true) bool foldersFirst,
    @Default(false) bool showDetails,
  }) = _FileExplorerSettings;
}

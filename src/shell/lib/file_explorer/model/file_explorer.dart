import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/screen/model/screen.serializable.dart';

part 'file_explorer.freezed.dart';

/// State of the overview's Files pane on one screen.
@freezed
abstract class FileExplorer with _$FileExplorer {
  const factory FileExplorer({
    required ScreenId screenId,
    required DirectoryPath path,
    @Default('') String filterText,
    @Default(true) bool isShowingHidden,

    /// An entry to select once the listing of [path] loads — for example the
    /// directory we came from when navigating up. Cleared once applied.
    DirectoryPath? pendingSelectedPath,
  }) = _FileExplorer;
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/overview/model/search_mode.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';

part 'overview.freezed.dart';

@freezed
abstract class Overview with _$Overview {
  factory Overview({
    required ScreenId screenId,
    required IList<EphemeralWindowId> windowList,
    required bool isDisplayed,

    /// The ephemeral window currently shown by the overview, or `null` when
    /// the list is empty. Kept so a specific window can be brought into view.
    EphemeralWindowId? focusedWindowId,

    /// The active search mode.
    @Default(SearchMode.application) SearchMode searchMode,

    /// The entry currently selected in the file explorer, shown as a preview in
    /// the content slot; `null` when nothing is selected.
    DirectoryPath? selectedPath,
  }) = _Overview;
}

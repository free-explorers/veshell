import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/overview/model/overview_content.dart';
import 'package:shell/overview/model/search_mode.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';

part 'overview.freezed.dart';

@freezed
abstract class Overview with _$Overview {
  factory Overview({
    required ScreenId screenId,

    /// The panel contents in creation order: ephemeral windows and file
    /// previews, without the implicit Helm.
    required IList<OverviewContent> contentList,
    required bool isDisplayed,

    /// [OverviewContent.contentId] of the displayed content. Defaults to the
    /// Helm, which is not stored in [contentList].
    @Default(helmContentId) String selectedContentId,

    /// Source of the next [OverviewContent.preview] id.
    @Default(0) int nextContentId,

    /// The active search mode.
    @Default(SearchMode.application) SearchMode searchMode,

    /// Index of the selected result in the active mode's list, or `null` when
    /// nothing is selected. The active mode's widget maps it back to its entry.
    int? selectedIndex,
  }) = _Overview;

  const Overview._();

  /// The content shown in the content region: the selected content, or the
  /// Helm when the selection is stale or names no content.
  OverviewContent get selectedContent => contentList.firstWhere(
    (content) => content.contentId == selectedContentId,
    orElse: () => const OverviewContent.helm(),
  );

  /// The ephemeral windows open in the overview, in panel order.
  IList<EphemeralWindowId> get windowList => contentList
      .whereType<WindowOverviewContent>()
      .map((content) => content.windowId)
      .toIList();
}

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/window/model/window_id.serializable.dart';

part 'overview_content.freezed.dart';

/// The [OverviewContent.contentId] of the Helm dashboard.
const helmContentId = 'helm';

/// One item shown by the overview's content panel and content region.
///
/// The panel is the Helm followed by `Overview.contentList`, so windows and
/// file previews are peers in creation order. New kinds are added as variants
/// here and then handled by the body and tab widgets; those switches are
/// exhaustive, so a new variant fails to compile until both handle it.
@freezed
sealed class OverviewContent with _$OverviewContent {
  const OverviewContent._();

  /// The Helm dashboard. Never stored in the Overview content list: it is the
  /// implicit first tab and the fallback when nothing else is selected.
  const factory OverviewContent.helm() = HelmOverviewContent;

  /// An ephemeral window's surface.
  const factory OverviewContent.window(EphemeralWindowId windowId) =
      WindowOverviewContent;

  /// A file preview owned by a panel tab.
  ///
  /// [id] is stable for the lifetime of the tab, so the selection survives a
  /// change of [entry]: while a preview is selected, selecting another file
  /// replaces [entry] in place instead of opening a new tab.
  const factory OverviewContent.preview({
    required int id,
    required FileEntry entry,
  }) = PreviewOverviewContent;

  /// Stable identity used to select and update this content.
  String get contentId => switch (this) {
    HelmOverviewContent() => helmContentId,
    WindowOverviewContent(:final windowId) => 'window:${windowId.uuid}',
    PreviewOverviewContent(:final id) => 'preview:$id',
  };

  /// Whether the panel offers a close action for this content.
  bool get isClosable => this is! HelmOverviewContent;
}

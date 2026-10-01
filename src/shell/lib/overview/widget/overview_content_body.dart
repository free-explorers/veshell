import 'package:material_ui/material_ui.dart';
import 'package:shell/file_preview/widget/file_preview_view.dart';
import 'package:shell/overview/helm/widget/helm.dart';
import 'package:shell/overview/model/overview_content.dart';
import 'package:shell/theme//provider/theme.dart';
import 'package:shell/window/widget/ephemeral_window.dart';

/// Renders the content region for a single [OverviewContent].
///
/// This is the only place that maps a content kind to its region widget, so a
/// new [OverviewContent] variant fails to compile until it is handled here.
class OverviewContentBody extends StatelessWidget {
  const OverviewContentBody({
    required this.content,
    required this.windowFocusNode,
    super.key,
  });

  final OverviewContent content;

  /// Focus node handed to the ephemeral window surface when [content] is a
  /// window. Unused for other kinds.
  final FocusNode windowFocusNode;

  @override
  Widget build(BuildContext context) {
    return switch (content) {
      HelmOverviewContent() => const Helm(),
      WindowOverviewContent(:final windowId) => ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(surfaceRadius)),
        child: EphemeralWindowWidget(
          key: ValueKey(windowId),
          windowId: windowId,
          focusNode: windowFocusNode,
        ),
      ),
      PreviewOverviewContent(:final entry) => FilePreviewView(
        key: ValueKey(entry),
        path: entry.path,
      ),
    };
  }
}

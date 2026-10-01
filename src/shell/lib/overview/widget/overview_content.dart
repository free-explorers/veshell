import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/model/overview_content.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview_content_body.dart';
import 'package:shell/overview/widget/overview_content_tab.dart';
import 'package:shell/screen/widget/current_screen_id.dart';

/// The overview's content region: a tab panel selecting the displayed content
/// and the content body below it.
class OverviewContentPane extends HookConsumerWidget {
  const OverviewContentPane({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);
    final selectedContent = ref.watch(
      overviewStateProvider(screenId).select((state) => state.selectedContent),
    );

    final node = useFocusNode();

    return Material(
      borderRadius: BorderRadius.circular(38),
      color: Theme.of(context).colorScheme.surface.withAlpha(200),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _OverviewContentPanel(),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  fit: StackFit.expand,
                  children: [...previousChildren, ?currentChild],
                ),
                child: OverviewContentBody(
                  key: ValueKey(selectedContent.contentId),
                  content: selectedContent,
                  windowFocusNode: node,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewContentPanel extends HookConsumerWidget {
  const _OverviewContentPanel();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);

    final contentList = ref.watch(
      overviewStateProvider(screenId).select((state) => state.contentList),
    );
    final selectedContentId = ref.watch(
      overviewStateProvider(
        screenId,
      ).select((state) => state.selectedContentId),
    );
    final notifier = ref.read(overviewStateProvider(screenId).notifier);

    // The Helm is always the first tab; the rest are the panel contents in
    // creation order.
    final tabList = <OverviewContent>[
      const OverviewContent.helm(),
      ...contentList,
    ];

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, content) in tabList.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              OverviewContentTab(
                content: content,
                isSelected: content.contentId == selectedContentId,
                onSelect: () => notifier.selectContent(content.contentId),
                onClose: () => notifier.closeContent(content.contentId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

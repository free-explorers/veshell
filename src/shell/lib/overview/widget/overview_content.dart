import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/model/overview_content.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview_content_body.dart';
import 'package:shell/overview/widget/overview_content_tab.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shared/widget/frosted_surface.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';

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

    final node = useFocusNode(debugLabel: 'OverviewWindowFocus');

    // Selecting a window's tab hands it the keyboard. `selectContent` is a
    // no-op when that window is already the displayed content (the common
    // re-click): nothing remounts, so the window widget's own focus hand-off
    // never runs and the keyboard would stay where it was (e.g. the search
    // field), where `Enter` would launch another instance.
    void selectContent(OverviewContent content) {
      ref
          .read(overviewStateProvider(screenId).notifier)
          .selectContent(content.contentId);
      if (content is WindowOverviewContent) {
        node.requestFocus();
      }
    }

    // Directional navigation inside the content pane (the Helm's controls, a
    // preview, an embedded window) uses the framework's directional focus:
    // the pane is made of focusable Material widgets, so traversal walks them.
    return Actions(
      actions: {
        NavigateIntent: CallbackAction<NavigateIntent>(
          onInvoke: (intent) {
            primaryFocus?.focusInDirection(switch (intent.direction) {
              NavigationDirection.up => TraversalDirection.up,
              NavigationDirection.down => TraversalDirection.down,
              NavigationDirection.left => TraversalDirection.left,
              NavigationDirection.right => TraversalDirection.right,
            });
            return null;
          },
        ),
      },
      child: FrostedSurface(
        borderRadius: BorderRadius.circular(38),
        tint: Theme.of(context).colorScheme.surface.withAlpha(200),
        noise: true,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _OverviewContentPanel(onSelect: selectContent),
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
        ),
      ),
    );
  }
}

class _OverviewContentPanel extends HookConsumerWidget {
  const _OverviewContentPanel({required this.onSelect});

  /// Selects a content; the pane uses it to also hand a selected window the
  /// keyboard.
  final ValueChanged<OverviewContent> onSelect;

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
                onSelect: () => onSelect(content),
                onClose: () => notifier.closeContent(content.contentId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/tileable.widget.dart';

class WorkspacePanel extends HookConsumerWidget implements PreferredSizeWidget {
  const WorkspacePanel({
    required this.tileableList,
    required this.tabController,
    super.key,
  });
  final List<Tileable> tileableList;
  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.brightness == Brightness.dark
          ? theme.colorScheme.surface
          : theme.colorScheme.primary,
      child: SizedBox(
        height: 48,
        child: TabBar.secondary(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          controller: tabController,
          tabs: [
            for (final tileable in tileableList)
              tileable.buildPanelWidget(context, ref),
          ],
        ),
      ),
    );
  }

  @override
  // TODO: implement preferredSize to expand width
  Size get preferredSize => const Size.fromHeight(48);
}

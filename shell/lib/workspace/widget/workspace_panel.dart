import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/workspace/widget/tileable/tileable.dart';
import 'package:shell/workspace/widget/tileable_list.dart';

class WorkspacePanel extends HookConsumerWidget implements PreferredSizeWidget {
  const WorkspacePanel({
    required this.tileableList,
    super.key,
  });
  final List<Tileable> tileableList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.brightness == Brightness.dark
          ? theme.colorScheme.surface
          : theme.colorScheme.primary,
      child: SizedBox(
        height: 48,
        child: TileableListView(
          tileableList: tileableList,
        ),
        /* child: TabBar.secondary(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          controller: tabController,
          tabs: [
            for (final tileable in tileableList)
              tileable.buildPanelWidget(context, ref),
          ],
        ), */
      ),
    );
  }

  @override
  // TODO: implement preferredSize to expand width
  Size get preferredSize => const Size.fromHeight(48);
}

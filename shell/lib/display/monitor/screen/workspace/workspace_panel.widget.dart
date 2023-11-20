import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:veshell/display/monitor/screen/workspace/tileable/tileable.widget.dart';

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
    return Material(
      color: const Color.fromARGB(255, 25, 25, 25),
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

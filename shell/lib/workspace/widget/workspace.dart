import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/util/app_launch.dart';
import 'package:shell/shared/widget/sliding_container.dart';
import 'package:shell/window/provider/window.manager.dart';
import 'package:shell/workspace/provider/workspace.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/persistent_application_launcher.dart';
import 'package:shell/workspace/widget/tileable/persistent_window/persistent_window.dart';
import 'package:shell/workspace/widget/tileable/tileable.dart';
import 'package:shell/workspace/widget/workspace_panel.dart';

class WorkspaceWidget extends HookConsumerWidget {
  const WorkspaceWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowManager = ref.watch(windowManagerProvider.notifier);
    final currentWorkspaceId = ref.watch(currentWorkspaceIdProvider);
    final workspaceState =
        ref.watch(workspaceStateProvider(currentWorkspaceId));
    final workspaceStateNotifier =
        ref.watch(workspaceStateProvider(currentWorkspaceId).notifier);
    final appLauncher = PersistentApplicationSelector(
      onSelect: (entry) {
        print('start ${entry.desktopEntry.id}');
        final newWindowId =
            windowManager.createPersistentWindowForDesktopEntry(entry);
        ref
            .read(workspaceStateProvider(currentWorkspaceId).notifier)
            .addWindow(newWindowId);
        launchDesktopEntry(entry.desktopEntry);
      },
    );

    final tileableList = <Tileable>[];
    for (final windowId in workspaceState.tileableWindowList) {
      tileableList.add(
        PersistentWindowTileable(
          windowId: windowId,
        ),
      );
    }
    tileableList.add(appLauncher);

    final tabController = useTabController(
      initialIndex: workspaceState.focusedIndex,
      initialLength: tileableList.length,
      keys: [workspaceState.tileableWindowList.length],
    );

    useEffect(
      () {
        tabController.addListener(() {
          ref
              .read(workspaceStateProvider(currentWorkspaceId).notifier)
              .setFocusedIndex(tabController.index);
        });
        return null;
      },
      [tabController],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkspacePanel(
          tileableList: tileableList,
          tabController: tabController,
        ),
        Expanded(
          child: SlidingContainer(
            index: tabController.index,
            children: tileableList,
          ),
        ),
      ],
    );
  }
}

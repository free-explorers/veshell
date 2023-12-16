import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/persistent_application_launcher/persistent_application_launcher.widget.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/persistent_window/persistent_window.widget.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/tileable.widget.dart';
import 'package:shell/display/monitor/screen/workspace/workspace.provider.dart';
import 'package:shell/display/monitor/screen/workspace/workspace_panel.widget.dart';
import 'package:shell/manager/window/window.manager.dart';
import 'package:shell/shared/util/app_launch.dart';
import 'package:shell/shared/widget/sliding_container.widget.dart';

class WorkspaceWidget extends HookConsumerWidget {
  const WorkspaceWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowManager = ref.watch(windowManagerProvider.notifier);
    final currentWorkspaceId = ref.watch(currentWorkspaceIdProvider);
    final workspaceState =
        ref.watch(workspaceStateProvider(currentWorkspaceId));
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

    final tabIndex = useState(0);
    final tabController = useTabController(
      initialLength: tileableList.length,
      keys: [workspaceState],
    );

    useEffect(
      () {
        tabController.addListener(() {
          tabIndex.value = tabController.index;
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

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/persistent_application_launcher/persistent_application_launcher.widget.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/persistent_window/persistent_window.widget.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/tileable.widget.dart';
import 'package:shell/display/monitor/screen/workspace/workspace_panel.widget.dart';
import 'package:shell/shared/state/window_stack/window_stack.provider.dart';
import 'package:shell/shared/widget/sliding_container.widget.dart';

class WorkspaceWidget extends HookConsumerWidget {
  const WorkspaceWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowStackList = ref.watch(windowStackProvider).windows;
    final tileableList = <Tileable>[
      const PersistentApplicationLauncher(),
    ];

    for (final surfaceId in windowStackList) {
      tileableList.add(
        PersistentWindowTileable(
          surfaceId: surfaceId,
        ),
      );
    }
    final tabIndex = useState(0);
    final tabController = useTabController(
      initialLength: tileableList.length,
      keys: [windowStackList],
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

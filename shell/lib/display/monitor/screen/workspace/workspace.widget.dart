import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/persistent_application_launcher/persistent_application_launcher.widget.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/persistent_window/persistent_window.widget.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/tileable.widget.dart';
import 'package:shell/display/monitor/screen/workspace/workspace_panel.widget.dart';
import 'package:shell/shared/state/window_stack/window_stack.provider.dart';
import 'package:shell/shared/wayland/xdg_popup/popup_stack.dart';

class WorkspaceWidget extends HookConsumerWidget {
  const WorkspaceWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowStackList = ref.watch(windowStackProvider).windows;
    final tileableList = <Tileable>[
      const PersistentApplicationLauncher(),
    ];

    for (final viewdId in windowStackList) {
      tileableList.add(
        PersistentWindowTileable(
          viewId: viewdId,
        ),
      );
    }
    final tabController = useTabController(
      initialLength: tileableList.length,
      keys: [windowStackList],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkspacePanel(
          tileableList: tileableList,
          tabController: tabController,
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final tileable in tileableList) tileable,
              const PopupStack(),
            ],
          ),
        ),
      ],
    );
  }
}

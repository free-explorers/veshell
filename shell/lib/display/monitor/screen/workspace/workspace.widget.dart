import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:veshell/display/monitor/screen/workspace/tileable/persistent_application_launcher/persistent_application_launcher.widget.dart';
import 'package:veshell/manager/window/window.dart';
import 'package:veshell/shared/state/window_stack/window_stack.provider.dart';

class WorkspaceWidget extends HookConsumerWidget {
  const WorkspaceWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowStackList = ref.watch(windowStackProvider).windows;
    return Stack(
      children: [
        const PersistentApplicationLauncher(),
        for (final viewId in windowStackList)
          Window(key: GlobalKey(), viewId: viewId),
      ],
    );
  }
}

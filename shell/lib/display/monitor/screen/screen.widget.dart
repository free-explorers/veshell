import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/display/monitor/screen/workspace/workspace.provider.dart';
import 'package:shell/display/monitor/screen/workspace/workspace.widget.dart';

/// Widget that represent the Screen in the widget tree
class ScreenWidget extends HookConsumerWidget {
  /// Const constructor
  const ScreenWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worskpaceIdList = ref.watch(workspaceManagerProvider).toKeyIList();
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final workspaceId in worskpaceIdList)
          ProviderScope(
            overrides: [
              currentWorkspaceIdProvider.overrideWith((ref) => workspaceId),
            ],
            child: const WorkspaceWidget(),
          ),
      ],
    );
  }
}

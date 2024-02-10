import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/screen/provider/current_screen_id.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/screen/widget/screen_panel.dart';
import 'package:shell/shared/widget/sliding_container.dart';
import 'package:shell/workspace/provider/current_workspace_id.dart';
import 'package:shell/workspace/widget/workspace.dart';

/// Widget that represent the Screen in the widget tree
class ScreenWidget extends HookConsumerWidget {
  /// Const constructor
  const ScreenWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = ref.watch(currentScreenIdProvider);
    final screenState = ref.watch(screenStateProvider(screenId));

    final workspaceList = [
      for (final workspaceId in screenState.workspaceList)
        ProviderScope(
          overrides: [
            currentWorkspaceIdProvider.overrideWith((ref) => workspaceId),
          ],
          child: const WorkspaceWidget(),
        ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenPanel(),
        Expanded(
          child: SlidingContainer(
            direction: Axis.vertical,
            index: screenState.selectedIndex,
            children: workspaceList,
          ),
        ),
      ],
    );
  }
}

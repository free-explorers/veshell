import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/screen/model/screen_shortcuts.dart';
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

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyW):
            const FocusWorkspaceAboveIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS):
            const FocusWorkspaceBelowIntent(),
      },
      child: Actions(
        actions: {
          FocusWorkspaceAboveIntent: CallbackAction<FocusWorkspaceAboveIntent>(
            onInvoke: (_) {
              final nextIndex = screenState.selectedIndex - 1;
              if (nextIndex >= 0) {
                ref
                    .read(screenStateProvider(screenId).notifier)
                    .selectWorkspace(nextIndex);
              }
              return null;
            },
          ),
          FocusWorkspaceBelowIntent: CallbackAction<FocusWorkspaceBelowIntent>(
            onInvoke: (_) {
              final nextIndex = screenState.selectedIndex + 1;
              if (nextIndex < screenState.workspaceList.length) {
                ref
                    .read(screenStateProvider(screenId).notifier)
                    .selectWorkspace(nextIndex);
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenPanel(),
              Expanded(
                child: SlidingContainer(
                  direction: Axis.vertical,
                  index: screenState.selectedIndex,
                  children: screenState.workspaceList
                      .map(
                        (workspaceId) => ProviderScope(
                          key: Key(workspaceId),
                          overrides: [
                            currentWorkspaceIdProvider
                                .overrideWith((ref) => workspaceId),
                          ],
                          child: const WorkspaceWidget(),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

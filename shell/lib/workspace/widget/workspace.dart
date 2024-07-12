import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/widget/sliding_container.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/workspace/model/workspace_shortcuts.dart';
import 'package:shell/workspace/provider/current_workspace_id.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/persistent_application_launcher.dart';
import 'package:shell/workspace/widget/tileable/persistent_window/persistent_window.dart';
import 'package:shell/workspace/widget/tileable/tileable.dart';
import 'package:shell/workspace/widget/workspace_panel.dart';

class WorkspaceWidget extends HookConsumerWidget {
  const WorkspaceWidget({required this.isSelected, super.key});

  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowManager = ref.watch(windowManagerProvider.notifier);
    final currentWorkspaceId = ref.watch(currentWorkspaceIdProvider);
    final workspaceState =
        ref.watch(workspaceStateProvider(currentWorkspaceId));

    final workspaceFocusScopeNode = useFocusScopeNode(
      debugLabel: 'WorkspaceScope',
    );

    useEffect(
      () {
        if (isSelected) {
          print(
            'workspaceFocusScopeNode.requestFocus ${workspaceState.tileableWindowList} ${workspaceState.selectedIndex}',
          );
          workspaceFocusScopeNode.requestFocus();
        }
        return null;
      },
      [isSelected],
    );

    final appLauncher = PersistentApplicationSelector(
      isSelected: workspaceState.selectedIndex ==
          workspaceState.tileableWindowList.length,
      onSelect: (entry) {
        print('start ${entry.desktopEntry.id}');
        final newWindowId =
            windowManager.createPersistentWindowForDesktopEntry(entry);

        ref
            .read(persistentWindowStateProvider(newWindowId).notifier)
            .launchSelf();

        ref
            .read(workspaceStateProvider(currentWorkspaceId).notifier)
            .addWindow(newWindowId);
      },
    );

    final tileableList = <Tileable>[];
    for (final (index, windowId) in workspaceState.tileableWindowList.indexed) {
      tileableList.add(
        PersistentWindowTileable(
          windowId: windowId,
          isSelected: workspaceState.selectedIndex == index,
          onGrabFocus: () => ref
              .read(workspaceStateProvider(currentWorkspaceId).notifier)
              .setSelectedIndex(index),
        ),
      );
    }
    tileableList.add(appLauncher);
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyA):
            const FocusLeftTileableIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyD):
            const FocusRightTileableIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyQ):
            const CloseTileableIntent(),
      },
      child: Actions(
        actions: {
          FocusLeftTileableIntent: CallbackAction<FocusLeftTileableIntent>(
            onInvoke: (_) {
              final nextIndex = workspaceState.selectedIndex - 1;
              if (nextIndex >= 0) {
                ref
                    .read(workspaceStateProvider(currentWorkspaceId).notifier)
                    .setSelectedIndex(nextIndex);
              }
              return null;
            },
          ),
          FocusRightTileableIntent: CallbackAction<FocusRightTileableIntent>(
            onInvoke: (_) {
              final nextIndex = workspaceState.selectedIndex + 1;
              if (nextIndex < tileableList.length) {
                ref
                    .read(workspaceStateProvider(currentWorkspaceId).notifier)
                    .setSelectedIndex(nextIndex);
              }
              return null;
            },
          ),
          CloseTileableIntent: CallbackAction<CloseTileableIntent>(
            onInvoke: (_) {
              final tileable = tileableList[workspaceState.selectedIndex];
              if (tileable is PersistentWindowTileable) {
                final persistentWindow =
                    ref.read(persistentWindowStateProvider(tileable.windowId));
                ref.read(windowManagerProvider.notifier).closeWindow(
                      persistentWindow.windowId,
                    );
              }

              return null;
            },
          ),
        },
        child: FocusScope(
          node: workspaceFocusScopeNode,
          onFocusChange: (value) {
            print('Focus changed $value for $currentWorkspaceId');
          },
          autofocus: isSelected,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WorkspacePanel(
                tileableList: tileableList,
                visibleLength: workspaceState.visibleLength,
                onVisibleLengthChange: (value) {
                  ref
                      .read(workspaceStateProvider(currentWorkspaceId).notifier)
                      .setVisibleLength(value);
                },
              ),
              Expanded(
                child: SlidingContainer(
                  index: workspaceState.selectedIndex,
                  visible: workspaceState.visibleLength,
                  children: tileableList,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

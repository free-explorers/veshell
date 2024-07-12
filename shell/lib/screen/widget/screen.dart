import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview.dart';
import 'package:shell/screen/model/screen_shortcuts.dart';
import 'package:shell/screen/provider/current_screen_id.dart';
import 'package:shell/screen/provider/focused_screen.dart';
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

    final screenFocusScopeNode =
        useFocusScopeNode(debugLabel: 'ScreenFocusNode');

    /* useEffect(
      () {
        onFocusChange() {
          if (screenFocusScopeNode.hasFocus) {
            screenFocusScopeNode.requestFocus();
          }
        }

        FocusManager.instance.addListener(onFocusChange);
        return () {
          FocusManager.instance.removeListener(onFocusChange);
        };
      },
      [],
    ); */
    final shortcutManager = useMemoized(ScreenShortcutManager.new, []);
    return Shortcuts.manager(
      manager: shortcutManager,
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
          ToggleOverviewIntent: CallbackAction<ToggleOverviewIntent>(
            onInvoke: (_) {
              print('In ToggleOverviewIntent');
              ref.read(overviewStateProvider(screenId).notifier).toggle();
              return null;
            },
          ),
        },
        child: MouseRegion(
          onEnter: (event) => screenFocusScopeNode.requestFocus(),
          child: FocusScope(
            node: screenFocusScopeNode,
            onFocusChange: (value) {
              if (value) {
                ref
                    .read(focusedScreenProvider.notifier)
                    .setFocusedScreen(screenId);
              }
            },
            child: Stack(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: SlidingContainer(
                        direction: Axis.vertical,
                        index: screenState.selectedIndex,
                        children: screenState.workspaceList
                            .mapIndexed(
                              (index, workspaceId) => ProviderScope(
                                key: Key(workspaceId),
                                overrides: [
                                  currentWorkspaceIdProvider
                                      .overrideWith((ref) => workspaceId),
                                ],
                                child: WorkspaceWidget(
                                  isSelected:
                                      screenState.selectedIndex == index,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const Material(
                      elevation: 4,
                      child: ScreenPanel(),
                    ),
                  ],
                ),
                const OverviewWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ScreenShortcutManager extends ShortcutManager {
  ScreenShortcutManager()
      : super(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyW):
                const FocusWorkspaceAboveIntent(),
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS):
                const FocusWorkspaceBelowIntent(),
          },
        );
  bool _isOverviewKeySolePressed = false;
  ToggleOverviewIntent overviewIntent = const ToggleOverviewIntent();
  final LogicalKeyboardKey overviewKey = LogicalKeyboardKey.meta;
  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    if (event is KeyUpEvent &&
        LogicalKeyboardKey.collapseSynonyms(event.logicalKey.synonyms)
            .contains(overviewKey) &&
        _isOverviewKeySolePressed) {
      _isOverviewKeySolePressed = false;
      final primaryContext = primaryFocus?.context;
      if (primaryContext != null) {
        final action = Actions.maybeFind<Intent>(
          primaryContext,
          intent: overviewIntent,
        );
        if (action != null) {
          final (bool enabled, Object? invokeResult) =
              Actions.of(primaryContext).invokeActionIfEnabled(
            action,
            overviewIntent,
            primaryContext,
          );
          if (enabled) {
            return action.toKeyEventResult(overviewIntent, invokeResult);
          }
        }
      }
    }

    _isOverviewKeySolePressed = event is KeyDownEvent &&
        LogicalKeyboardKey.collapseSynonyms(event.logicalKey.synonyms)
            .contains(overviewKey);

    return super.handleKeypress(context, event);
  }
}

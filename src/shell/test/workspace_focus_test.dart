import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/screen/model/screen_manager_state.serializable.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_manager_state.serializable.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/persistent_application_launcher.dart';
import 'package:shell/workspace/widget/workspace.dart';

const _screen = 'screen-1';
const _workspace = 'ws-1';

class _FakeWindowManager extends WindowManager {
  @override
  WindowManagerState build() => WindowManagerState(windows: <WindowId>{}.lock);
}

class _FakeWorkspaceState extends WorkspaceState {
  @override
  Workspace build(WorkspaceId workspaceId) => Workspace(
    workspaceId: workspaceId,
    tileableWindowList: <PersistentWindowId>[].lock,
    selectedIndex: 0,
    visibleLength: 1,
  );
}

/// Whether the primary focus currently lives inside [WorkspaceWidget], which is
/// what keeps the screen-level hotkeys working.
bool _focusIsInWorkspace() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.findAncestorWidgetOfExactType<WorkspaceWidget>() != null;
}

/// Whether focus reached a child (the launcher search field) rather than being
/// parked on the workspace scope itself.
bool _focusIsInSearchField() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.findAncestorWidgetOfExactType<TextField>() != null;
}

void main() {
  testWidgets('a workspace regains focus when reselected', (tester) async {
    final selected = ValueNotifier(true);
    addTearDown(selected.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          screenManagerProvider.overrideWithValue(
            ScreenManagerState(screenIds: {_screen}.lock),
          ),
          windowManagerProvider.overrideWith(_FakeWindowManager.new),
          workspaceStateProvider(
            _workspace,
          ).overrideWith(_FakeWorkspaceState.new),
          appDrawerFilteredDesktopEntriesProvider(
            '',
          ).overrideWith((ref) async => <LocalizedDesktopEntry>[]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CurrentScreenId(
            screenId: _screen,
            child: Scaffold(
              body: FocusScope(
                child: ValueListenableBuilder<bool>(
                  valueListenable: selected,
                  builder: (context, isSelected, _) => Center(
                    child: SizedBox(
                      width: 400,
                      height: 400,
                      child: WorkspaceWidget(
                        workspaceId: _workspace,
                        isSelected: isSelected,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The launcher's search field autofocuses on mount.
    expect(_focusIsInWorkspace(), isTrue);

    // Deselecting the workspace drops its focus.
    selected.value = false;
    await tester.pumpAndSettle();
    expect(_focusIsInWorkspace(), isFalse);

    // Reselecting it must move focus back into the workspace even though the
    // page was never deactivated, so `FocusScope.autofocus` alone would no-op.
    selected.value = true;
    await tester.pumpAndSettle();
    expect(_focusIsInWorkspace(), isTrue);

    // The workspace scope must not make its descendants unfocusable: the
    // launcher search field is still reachable and can take focus.
    await tester.tap(
      find.descendant(
        of: find.byType(PersistentApplicationSelector),
        matching: find.byType(TextField),
      ),
    );
    await tester.pumpAndSettle();
    expect(_focusIsInSearchField(), isTrue);
  });
}

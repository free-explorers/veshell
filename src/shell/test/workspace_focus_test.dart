import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/monitor_by_view_id.dart';
import 'package:shell/monitor/provider/platform_focused_view.dart';
import 'package:shell/screen/model/screen_manager_state.serializable.dart';
import 'package:shell/screen/provider/screen_for_view.dart';
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

const _mode = Mode(size: Size(1920, 1080), refreshRate: 60000);

/// A minimal connected-monitor projection for the providers under test.
Monitor _monitor(String name, {required int viewId}) => Monitor(
  name: name,
  description: '$name panel',
  physicalProperties: const PhysicalProperties(
    size: Size(600, 340),
    make: 'Acme',
    model: 'Panel',
  ),
  scale: 1,
  location: Offset.zero,
  currentMode: _mode,
  preferredMode: _mode,
  modes: const [_mode],
  viewId: viewId,
);

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

/// The workspace that currently owns the primary focus, or `null`.
String? _focusedWorkspaceId() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  return context.findAncestorWidgetOfExactType<WorkspaceWidget>()?.workspaceId;
}

void main() {
  testWidgets('a workspace regains focus when reselected', (tester) async {
    final selected = ValueNotifier(true);
    addTearDown(selected.dispose);

    final container = ProviderContainer(
      overrides: [
        screenManagerProvider.overrideWithValue(
          ScreenManagerState(screenIds: {_screen}.lock),
        ),
        // The compositor focuses the monitor that renders `_screen`.
        monitorByViewIdProvider(1).overrideWithValue('M'),
        screenForViewProvider(1).overrideWithValue(_screen),
        windowManagerProvider.overrideWith(_FakeWindowManager.new),
        workspaceStateProvider(
          _workspace,
        ).overrideWith(_FakeWorkspaceState.new),
        appDrawerFilteredDesktopEntriesProvider(
          '',
        ).overrideWith((ref) async => <LocalizedDesktopEntry>[]),
      ],
    );
    addTearDown(container.dispose);
    container.read(platformFocusedViewIdProvider.notifier).set(1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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

  testWidgets('only the compositor-focused screen grabs workspace focus', (
    tester,
  ) async {
    const screenA = 'screen-a';
    const screenB = 'screen-b';
    const workspaceA = 'ws-a';
    const workspaceB = 'ws-b';

    final container = ProviderContainer(
      overrides: [
        // Persisted order puts screen B first: the old `screenIds.first`
        // fallback picked it, while the compositor's first output (view 7)
        // renders screen A.
        screenManagerProvider.overrideWithValue(
          ScreenManagerState(screenIds: {screenB, screenA}.lock),
        ),
        connectedMonitorListProvider.overrideWithValue([
          _monitor('DP-1', viewId: 7),
          _monitor('HDMI-1', viewId: 8),
        ]),
        windowManagerProvider.overrideWith(_FakeWindowManager.new),
        workspaceStateProvider(
          workspaceA,
        ).overrideWith(_FakeWorkspaceState.new),
        workspaceStateProvider(
          workspaceB,
        ).overrideWith(_FakeWorkspaceState.new),
        appDrawerFilteredDesktopEntriesProvider(
          '',
        ).overrideWith((ref) async => <LocalizedDesktopEntry>[]),
        monitorByViewIdProvider(7).overrideWithValue('DP-1'),
        screenForViewProvider(7).overrideWithValue(screenA),
        monitorByViewIdProvider(8).overrideWithValue('HDMI-1'),
        screenForViewProvider(8).overrideWithValue(screenB),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: Column(
              children: [
                Expanded(
                  child: CurrentScreenId(
                    screenId: screenA,
                    child: WorkspaceWidget(
                      workspaceId: workspaceA,
                      isSelected: true,
                    ),
                  ),
                ),
                Expanded(
                  child: CurrentScreenId(
                    screenId: screenB,
                    child: WorkspaceWidget(
                      workspaceId: workspaceB,
                      isSelected: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both screens mount a selected workspace. Without a platform report the
    // gate uses the first connected monitor (the compositor seeds the pointer
    // on the first output), not the persisted `screenIds.first`.
    expect(_focusedWorkspaceId(), workspaceA);

    // The compositor reports the monitor under the pointer (HDMI, view 8):
    // focus follows it and leaves screen A.
    container.read(platformFocusedViewIdProvider.notifier).set(8);
    await tester.pumpAndSettle();

    expect(_focusedWorkspaceId(), workspaceB);
  });
}

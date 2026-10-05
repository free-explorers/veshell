import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide Notification;
import 'package:shell/capture/provider/recording_workspaces.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/provider/notification_routing.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/screen/provider/workspace_display_mode.dart';
import 'package:shell/screen/widget/workspace_list.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:shell/workspace/widget/tileable/persistent_window/persistent_window.dart';

const _screen = 'screen-1';
const _workspace = 'ws-1';
const _window = PersistentWindowId('w1');

class _FixedScreenState extends ScreenState {
  _FixedScreenState(this._screen);
  final Screen _screen;

  @override
  Screen build(ScreenId screenId) => _screen;
}

class _FixedWindowState extends PersistentWindowState {
  @override
  PersistentWindow build(PersistentWindowId windowId) => PersistentWindow(
    windowId: windowId,
    properties: const WindowProperties(appId: 'test'),
  );
}

/// Records the windows dropped onto the workspace so the test can assert the
/// drop reached [WorkspaceState.addWindow].
class _RecordingWorkspaceState extends WorkspaceState {
  _RecordingWorkspaceState(this._workspace);
  final Workspace _workspace;
  final addedWindows = <PersistentWindowId>[];

  @override
  Workspace build(WorkspaceId workspaceId) => _workspace;

  @override
  Future<void> addWindow(
    PersistentWindowId windowId, {
    bool selectWindow = false,
  }) async {
    addedWindows.add(windowId);
  }
}

void main() {
  for (final alreadyHere in [false, true]) {
    testWidgets('workspace button drop: alreadyHere=$alreadyHere', (
      tester,
    ) async {
      final workspace = _RecordingWorkspaceState(
        Workspace(
          workspaceId: _workspace,
          tileableWindowList: IList<PersistentWindowId>(
            alreadyHere ? [_window] : [],
          ),
          category: WorkspaceCategory.System,
          selectedIndex: 0,
          visibleLength: 1,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            screenStateProvider(_screen).overrideWith(
              () => _FixedScreenState(
                Screen(
                  screenId: _screen,
                  workspaceList: const IListConst<String>([_workspace]),
                  selectedIndex: 0,
                ),
              ),
            ),
            workspaceStateProvider(_workspace).overrideWith(() => workspace),
            persistentWindowStateProvider(
              _window,
            ).overrideWith(_FixedWindowState.new),
            currentWorkspaceDisplayModeProvider.overrideWithValue(
              WorkspaceDisplayMode.category,
            ),
            unreadNotificationsForWorkspaceProvider(
              _workspace,
            ).overrideWithValue(const IListConst<Notification>([])),
            recordingWorkspacesProvider.overrideWithValue(
              const ISetConst<WorkspaceId>({}),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: WorkspaceListButton(
                      workspaceId: _workspace,
                      screenId: _screen,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Draggable<PersistentWindowTileable>(
                        data: PersistentWindowTileable(
                          windowId: _window,
                          isSelected: false,
                        ),
                        feedback: SizedBox(
                          width: 50,
                          height: 50,
                          child: ColoredBox(color: Colors.red),
                        ),
                        child: SizedBox(
                          key: ValueKey('drag-source'),
                          width: 50,
                          height: 50,
                          child: ColoredBox(color: Colors.green),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('drag-source'))),
      );
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(WorkspaceListButton)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(workspace.addedWindows, alreadyHere ? isEmpty : [_window]);
    });
  }
}

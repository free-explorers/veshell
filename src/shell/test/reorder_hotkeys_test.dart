import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

const _screen = 'screen-1';
const _workspace = 'ws-1';

class _FakeScreenState extends ScreenState {
  _FakeScreenState(this._screen);
  final Screen _screen;

  @override
  Screen build(ScreenId screenId) => _screen;
}

class _FakeWorkspaceState extends WorkspaceState {
  _FakeWorkspaceState(this._workspace);
  final Workspace _workspace;

  @override
  Workspace build(WorkspaceId workspaceId) => _workspace;
}

/// A workspace that records `insertWindow` instead of mutating state, so a
/// cross-workspace move can be asserted without the async category lookup.
class _RecordingWorkspaceState extends WorkspaceState {
  _RecordingWorkspaceState({required this.workspace, required this.calls});

  final Workspace workspace;
  final List<(PersistentWindowId, int, bool)> calls;

  @override
  Workspace build(WorkspaceId workspaceId) => workspace;

  @override
  Future<void> insertWindow(
    PersistentWindowId windowId,
    int index, {
    bool selectWindow = false,
  }) async {
    calls.add((windowId, index, selectWindow));
  }
}

Screen _screenWith(List<String> workspaces, {int selectedIndex = 0}) => Screen(
  screenId: _screen,
  workspaceList: workspaces.lock,
  selectedIndex: selectedIndex,
);

Workspace _workspaceWith(List<String> windows, {int selectedIndex = 0}) =>
    Workspace(
      workspaceId: _workspace,
      tileableWindowList: windows.map(PersistentWindowId.new).toList().lock,
      selectedIndex: selectedIndex,
      visibleLength: 1,
    );

void main() {
  group('move hotkeys are wired', () {
    test('action ids match the settings keys', () {
      expect(HotkeysAction.moveUp.actionId, 'navigation.moveUp');
      expect(HotkeysAction.moveDown.actionId, 'navigation.moveDown');
      expect(HotkeysAction.moveLeft.actionId, 'navigation.moveLeft');
      expect(HotkeysAction.moveRight.actionId, 'navigation.moveRight');
    });

    test('action ids map to the directional move intents', () {
      final directions = {
        HotkeysAction.moveUp: NavigationDirection.up,
        HotkeysAction.moveDown: NavigationDirection.down,
        HotkeysAction.moveLeft: NavigationDirection.left,
        HotkeysAction.moveRight: NavigationDirection.right,
      };
      for (final MapEntry(key: action, value: direction)
          in directions.entries) {
        expect(
          getActionIntent(action),
          isA<MoveIntent>().having(
            (intent) => intent.direction,
            'direction',
            direction,
          ),
        );
      }
    });
  });

  group('workspace reordering', () {
    late ProviderContainer container;
    late _FakeScreenState screenState;

    void setUpScreen(List<String> workspaces, {int selectedIndex = 0}) {
      screenState = _FakeScreenState(
        _screenWith(workspaces, selectedIndex: selectedIndex),
      );
      container = ProviderContainer(
        overrides: [
          screenStateProvider(_screen).overrideWith(() => screenState),
        ],
      );
      addTearDown(container.dispose);
    }

    ScreenState notifier() =>
        container.read(screenStateProvider(_screen).notifier);

    Screen current() => container.read(screenStateProvider(_screen));

    test('moves the selected workspace up and keeps it selected', () {
      setUpScreen(['a', 'b', 'blank'], selectedIndex: 1);

      notifier().moveSelectedWorkspaceAbove();

      expect(current().workspaceList.toList(), ['b', 'a', 'blank']);
      expect(current().selectedIndex, 0);
    });

    test('moves the selected workspace down and keeps it selected', () {
      setUpScreen(['a', 'b', 'blank']);

      notifier().moveSelectedWorkspaceBelow();

      expect(current().workspaceList.toList(), ['b', 'a', 'blank']);
      expect(current().selectedIndex, 1);
    });

    test('does not move the first workspace up', () {
      setUpScreen(['a', 'b', 'blank']);

      notifier().moveSelectedWorkspaceAbove();

      expect(current().workspaceList.toList(), ['a', 'b', 'blank']);
      expect(current().selectedIndex, 0);
    });

    test('does not move a workspace down into the new-workspace slot', () {
      setUpScreen(['a', 'b', 'blank'], selectedIndex: 1);

      notifier().moveSelectedWorkspaceBelow();

      expect(current().workspaceList.toList(), ['a', 'b', 'blank']);
      expect(current().selectedIndex, 1);
    });

    test('does not move the pinned last workspace', () {
      setUpScreen(['a', 'b', 'blank'], selectedIndex: 2);

      notifier()
        ..moveSelectedWorkspaceAbove()
        ..moveSelectedWorkspaceBelow();

      expect(current().workspaceList.toList(), ['a', 'b', 'blank']);
      expect(current().selectedIndex, 2);
    });
  });

  group('tileable reordering', () {
    late ProviderContainer container;
    late _FakeWorkspaceState workspaceState;

    void setUpWorkspace(List<String> windows, {int selectedIndex = 0}) {
      workspaceState = _FakeWorkspaceState(
        _workspaceWith(windows, selectedIndex: selectedIndex),
      );
      container = ProviderContainer(
        overrides: [
          workspaceStateProvider(_workspace).overrideWith(() => workspaceState),
        ],
      );
      addTearDown(container.dispose);
    }

    WorkspaceState notifier() =>
        container.read(workspaceStateProvider(_workspace).notifier);

    Workspace current() => container.read(workspaceStateProvider(_workspace));

    test('moves the selected window left and keeps it selected', () {
      setUpWorkspace(['t1', 't2', 't3'], selectedIndex: 1);

      notifier().moveSelectedWindowLeft();

      expect(current().tileableWindowList.map((e) => e.uuid).toList(), [
        't2',
        't1',
        't3',
      ]);
      expect(current().selectedIndex, 0);
    });

    test('moves the selected window right and keeps it selected', () {
      setUpWorkspace(['t1', 't2', 't3'], selectedIndex: 1);

      notifier().moveSelectedWindowRight();

      expect(current().tileableWindowList.map((e) => e.uuid).toList(), [
        't1',
        't3',
        't2',
      ]);
      expect(current().selectedIndex, 2);
    });

    test('does not move the first window left', () {
      setUpWorkspace(['t1', 't2']);

      notifier().moveSelectedWindowLeft();

      expect(current().tileableWindowList.map((e) => e.uuid).toList(), [
        't1',
        't2',
      ]);
      expect(current().selectedIndex, 0);
    });

    test('does not move the last window into the launcher slot', () {
      setUpWorkspace(['t1', 't2'], selectedIndex: 1);

      notifier().moveSelectedWindowRight();

      expect(current().tileableWindowList.map((e) => e.uuid).toList(), [
        't1',
        't2',
      ]);
      expect(current().selectedIndex, 1);
    });

    test('does not reorder the application launcher', () {
      // The launcher is the virtual slot at index `tileableWindowList.length`.
      setUpWorkspace(['t1', 't2'], selectedIndex: 2);

      notifier()
        ..moveSelectedWindowLeft()
        ..moveSelectedWindowRight();

      expect(current().tileableWindowList.map((e) => e.uuid).toList(), [
        't1',
        't2',
      ]);
      expect(current().selectedIndex, 2);
    });
  });

  group('moving a tileable between workspaces', () {
    late List<(PersistentWindowId, int, bool)> calls;

    ProviderContainer setUpScreen({
      required int selectedWorkspace,
      required int selectedWindow,
      int windowCount = 2,
    }) {
      calls = [];
      final container = ProviderContainer(
        overrides: [
          screenStateProvider(_screen).overrideWith(
            () => _FakeScreenState(
              _screenWith([
                'ws-a',
                'ws-b',
                'ws-c',
              ], selectedIndex: selectedWorkspace),
            ),
          ),
          workspaceStateProvider('ws-a').overrideWith(
            () => _RecordingWorkspaceState(
              workspace: _workspaceWith(
                ['t1', 't2'].take(windowCount).toList(),
                selectedIndex: selectedWindow,
              ),
              calls: calls,
            ),
          ),
          workspaceStateProvider('ws-b').overrideWith(
            () => _RecordingWorkspaceState(
              workspace: _workspaceWith(['b1'], selectedIndex: 0),
              calls: calls,
            ),
          ),
          workspaceStateProvider('ws-c').overrideWith(
            () => _RecordingWorkspaceState(
              workspace: _workspaceWith([], selectedIndex: 0),
              calls: calls,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    ScreenState notifier(ProviderContainer container) =>
        container.read(screenStateProvider(_screen).notifier);

    int selectedWorkspace(ProviderContainer container) =>
        container.read(screenStateProvider(_screen)).selectedIndex;

    test('sends the selected window to the workspace below and follows it', () {
      final container = setUpScreen(selectedWorkspace: 0, selectedWindow: 1);

      notifier(container).moveSelectedTileableToWorkspace(1);

      // Appended after ws-b's existing tile and selected there.
      expect(calls, [(PersistentWindowId.new('t2'), 1, true)]);
      // The screen navigates to the destination so the tile is followed.
      expect(selectedWorkspace(container), 1);
    });

    test('sends the selected window to the workspace above and follows it', () {
      // ws-b's first tile, appended after ws-a's two tiles.
      final container = setUpScreen(selectedWorkspace: 1, selectedWindow: 0);

      notifier(container).moveSelectedTileableToWorkspace(-1);

      expect(calls, [(PersistentWindowId.new('b1'), 2, true)]);
      expect(selectedWorkspace(container), 0);
    });

    test('does nothing at the edge of the workspace list', () {
      final container = setUpScreen(selectedWorkspace: 0, selectedWindow: 0);

      notifier(container).moveSelectedTileableToWorkspace(-1);

      expect(calls, isEmpty);
      expect(selectedWorkspace(container), 0);
    });

    test('does nothing when the application launcher is selected', () {
      // Two windows, so index 2 is the launcher slot.
      final container = setUpScreen(selectedWorkspace: 0, selectedWindow: 2);

      notifier(container).moveSelectedTileableToWorkspace(1);

      expect(calls, isEmpty);
      expect(selectedWorkspace(container), 0);
    });
  });
}

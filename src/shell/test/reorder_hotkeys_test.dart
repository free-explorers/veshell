import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/model/workspace_shortcuts.dart';
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
  group('reorder hotkeys are wired', () {
    test('action ids match the settings keys', () {
      expect(
        HotkeysAction.reorderWorkspaceAbove.actionId,
        'screen.reorderWorkspaceAbove',
      );
      expect(
        HotkeysAction.reorderWorkspaceBelow.actionId,
        'screen.reorderWorkspaceBelow',
      );
      expect(
        HotkeysAction.reorderLeftTileable.actionId,
        'workspace.reorderLeftTileable',
      );
      expect(
        HotkeysAction.reorderRightTileable.actionId,
        'workspace.reorderRightTileable',
      );
    });

    test('action ids map to the reorder intents', () {
      expect(
        getActionIntent(HotkeysAction.reorderWorkspaceAbove),
        isA<ReorderWorkspaceAboveIntent>(),
      );
      expect(
        getActionIntent(HotkeysAction.reorderWorkspaceBelow),
        isA<ReorderWorkspaceBelowIntent>(),
      );
      expect(
        getActionIntent(HotkeysAction.reorderLeftTileable),
        isA<ReorderLeftTileableIntent>(),
      );
      expect(
        getActionIntent(HotkeysAction.reorderRightTileable),
        isA<ReorderRightTileableIntent>(),
      );
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
}

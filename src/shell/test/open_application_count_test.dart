import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/available_screen_list.dart';
import 'package:shell/screen/provider/open_application_count.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

/// The workspaces of each screen.
const _workspacesOfScreen = {
  'shown': ['ws-1', 'ws-2'],
  'hidden-a': ['ws-3'],
  'hidden-b': ['ws-4'],
};

/// The tiles of each workspace, and whether each one runs its application.
const _tilesOfWorkspace = {
  'ws-1': {'w1': true, 'w2': false},
  'ws-2': {'w3': true},
  'ws-3': {'w4': true, 'w5': true},
  'ws-4': {'w6': false},
};

class _FixedScreenState extends ScreenState {
  @override
  Screen build(ScreenId screenId) => Screen(
    screenId: screenId,
    workspaceList: _workspacesOfScreen[screenId]!.lock,
    selectedIndex: 0,
  );
}

class _FixedWorkspaceState extends WorkspaceState {
  @override
  Workspace build(WorkspaceId workspaceId) => Workspace(
    workspaceId: workspaceId,
    tileableWindowList: _tilesOfWorkspace[workspaceId]!.keys
        .map(PersistentWindowId.new)
        .toIList(),
    selectedIndex: 0,
    visibleLength: 1,
  );
}

class _FixedWindowState extends PersistentWindowState {
  @override
  PersistentWindow build(PersistentWindowId windowId) => PersistentWindow(
    windowId: windowId,
    properties: const WindowProperties(appId: 'app'),
    metaWindowId: _isRunning(windowId.uuid) ? 'meta-${windowId.uuid}' : null,
  );

  static bool _isRunning(String uuid) => _tilesOfWorkspace.values.firstWhere(
    (tiles) => tiles.containsKey(uuid),
  )[uuid]!;
}

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      availableScreenListProvider.overrideWithValue(
        {'hidden-a', 'hidden-b'}.lock,
      ),
      for (final screenId in _workspacesOfScreen.keys)
        screenStateProvider(screenId).overrideWith(_FixedScreenState.new),
      for (final workspaceId in _tilesOfWorkspace.keys)
        workspaceStateProvider(
          workspaceId,
        ).overrideWith(_FixedWorkspaceState.new),
      for (final tiles in _tilesOfWorkspace.values)
        for (final uuid in tiles.keys)
          persistentWindowStateProvider(
            PersistentWindowId(uuid),
          ).overrideWith(_FixedWindowState.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a screen counts the running tiles of all its workspaces', () {
    final container = _container();

    expect(container.read(openApplicationCountForScreenProvider('shown')), 2);
    expect(
      container.read(openApplicationCountForScreenProvider('hidden-b')),
      0,
    );
  });

  test('the hidden count adds up only the screens no monitor shows', () {
    final container = _container();

    expect(container.read(hiddenOpenApplicationCountProvider), 2);
  });
}

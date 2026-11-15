import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';
import 'package:shell/window/provider/window_manager/windows_available_for_matching.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

const _screenId = 'screen';
const _workspaceId = 'workspace';
const _codeA = PersistentWindowId('code-a');
const _codeB = PersistentWindowId('code-b');
const _metaCodeA = 'meta-code-a';
const _metaCodeB = 'meta-code-b';
const _metaNested = 'meta-nested';

/// Every Code OSS window belongs to one Electron process.
const _codePid = 42;

class _FixedMetaWindowState extends MetaWindowState {
  _FixedMetaWindowState(this._window);
  final MetaWindow _window;

  @override
  MetaWindow build(String id) => _window;
}

class _FixedPersistentWindowState extends PersistentWindowState {
  _FixedPersistentWindowState(this._window);
  final PersistentWindow _window;

  @override
  PersistentWindow build(PersistentWindowId windowId) => _window;
}

class _FixedScreenState extends ScreenState {
  @override
  Screen build(ScreenId screenId) => Screen(
    screenId: screenId,
    workspaceList: const [_workspaceId].lock,
    selectedIndex: 0,
  );
}

class _FixedWorkspaceState extends WorkspaceState {
  _FixedWorkspaceState(this._selectedIndex);
  final int _selectedIndex;

  @override
  Workspace build(WorkspaceId workspaceId) => Workspace(
    workspaceId: workspaceId,
    tileableWindowList: const [_codeA, _codeB].lock,
    selectedIndex: _selectedIndex,
    visibleLength: 2,
  );
}

class _FixedFocusedScreen extends FocusedScreen {
  @override
  ScreenId? build() => _screenId;
}

MetaWindow _metaWindow(String id, {String? appId}) => MetaWindow(
  id: id,
  pid: _codePid,
  mapped: true,
  surfaceId: 0,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
  appId: appId,
);

PersistentWindow _tile(PersistentWindowId id, String metaWindowId) =>
    PersistentWindow(
      windowId: id,
      properties: const WindowProperties(appId: 'code-oss'),
      metaWindowId: metaWindowId,
    );

ProviderContainer _container({required int selectedTileIndex}) {
  final container = ProviderContainer(
    overrides: [
      metaWindowStateProvider(_metaCodeA).overrideWith(
        () => _FixedMetaWindowState(_metaWindow(_metaCodeA, appId: 'code-oss')),
      ),
      metaWindowStateProvider(_metaCodeB).overrideWith(
        () => _FixedMetaWindowState(_metaWindow(_metaCodeB, appId: 'code-oss')),
      ),
      // A window opened from Code OSS that reports no identity of its own.
      metaWindowStateProvider(
        _metaNested,
      ).overrideWith(() => _FixedMetaWindowState(_metaWindow(_metaNested))),
      persistentWindowStateProvider(_codeA).overrideWith(
        () => _FixedPersistentWindowState(_tile(_codeA, _metaCodeA)),
      ),
      persistentWindowStateProvider(_codeB).overrideWith(
        () => _FixedPersistentWindowState(_tile(_codeB, _metaCodeB)),
      ),
      windowsAvailableForMatchingProvider.overrideWithValue(const [
        _codeA,
        _codeB,
      ]),
      focusedScreenProvider.overrideWith(_FixedFocusedScreen.new),
      screenStateProvider(_screenId).overrideWith(_FixedScreenState.new),
      workspaceStateProvider(
        _workspaceId,
      ).overrideWith(() => _FixedWorkspaceState(selectedTileIndex)),
    ],
  );
  addTearDown(container.dispose);
  container.read(metaWindowWindowMapProvider.notifier)
    ..set(_metaCodeA, _codeA)
    ..set(_metaCodeB, _codeB);
  return container;
}

void main() {
  // Regression: a nested Veshell started from the second Code OSS window
  // became a dialog of the first one, the first same-process sibling found.
  test('a same-process window attaches to the focused sibling tile', () {
    final container = _container(selectedTileIndex: 1);
    final engine = container.read(matchingEngineProvider.notifier);

    expect(engine.dialogOwnerFromRelation(_metaNested), _codeB);
  });

  test('without a focused sibling, the first sibling is kept', () {
    // The launcher slot (past the last tile) is selected.
    final container = _container(selectedTileIndex: 2);
    final engine = container.read(matchingEngineProvider.notifier);

    expect(engine.dialogOwnerFromRelation(_metaNested), _codeA);
  });
}

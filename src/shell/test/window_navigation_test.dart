import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/model/screen_manager_state.serializable.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/window_navigation.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

const _screen1 = 'screen-1';
const _screen2 = 'screen-2';
const _workspace1 = 'ws-1';
const _workspace3 = 'ws-3';
const _windowC = PersistentWindowId('window-c');
const _dialog = DialogWindowId('dialog');

/// A read-only `Ref` for exercising the navigation functions directly.
final _refProvider = Provider<Ref>((ref) => ref);

class _RecordingScreenState extends ScreenState {
  _RecordingScreenState(this._screen);
  final Screen _screen;
  final selectedIndices = <int>[];

  @override
  Screen build(ScreenId screenId) => _screen;

  @override
  void selectWorkspace(int index) {
    selectedIndices.add(index);
    state = state.copyWith(selectedIndex: index);
  }
}

class _RecordingWorkspaceState extends WorkspaceState {
  _RecordingWorkspaceState(this._workspace);
  final Workspace _workspace;
  PersistentWindowId? selectedWindow;

  @override
  Workspace build(WorkspaceId workspaceId) => _workspace;

  @override
  void selectWindow(PersistentWindowId windowId) {
    selectedWindow = windowId;
    state = state.copyWith(
      selectedIndex: _workspace.tileableWindowList.indexOf(windowId),
    );
  }
}

class _FixedDialogState extends DialogWindowState {
  _FixedDialogState(this._dialog);
  final DialogWindow _dialog;

  @override
  DialogWindow build(DialogWindowId windowId) => _dialog;
}

Screen _screen(String id, List<String> workspaces) => Screen(
  screenId: id,
  workspaceList: workspaces.lock,
  selectedIndex: 0,
);

Workspace _workspace(String id, List<PersistentWindowId> windows) => Workspace(
  workspaceId: id,
  tileableWindowList: windows.lock,
  selectedIndex: 0,
  visibleLength: 1,
);

void main() {
  late _RecordingScreenState screen1;
  late _RecordingScreenState screen2;
  late _RecordingWorkspaceState workspace3;
  late ProviderContainer container;
  late Ref ref;

  setUp(() {
    screen1 = _RecordingScreenState(_screen(_screen1, const [_workspace1]));
    screen2 = _RecordingScreenState(_screen(_screen2, const [_workspace3]));
    workspace3 = _RecordingWorkspaceState(
      _workspace(_workspace3, const [_windowC]),
    );
    container = ProviderContainer(
      overrides: [
        screenManagerProvider.overrideWithValue(
          ScreenManagerState(
            screenIds: {_screen1, _screen2}.lock,
          ),
        ),
        screenStateProvider(_screen1).overrideWith(() => screen1),
        screenStateProvider(_screen2).overrideWith(() => screen2),
        workspaceStateProvider(_workspace3).overrideWith(() => workspace3),
        windowWorkspaceMapProvider.overrideWithValue(
          <WindowId, WorkspaceId>{_windowC: _workspace3}.lock,
        ),
        metaWindowWindowMapProvider.overrideWithValue(
          <MetaWindowId, WindowId>{'meta-c': _windowC}.lock,
        ),
        dialogWindowStateProvider(_dialog).overrideWith(
          () => _FixedDialogState(
            const DialogWindow(
              windowId: _dialog,
              properties: WindowProperties(appId: 'app'),
              metaWindowId: 'meta-dialog',
              parentWindowId: _windowC,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Keep the focused screen and the request-scoped Ref alive.
    container
      ..listen(focusedScreenProvider, (_, _) {})
      ..listen(_refProvider, (_, _) {});
    ref = container.read(_refProvider);
  });

  test('a persistent window selects its workspace and tile on its screen', () {
    bringWindowIntoView(ref, _windowC);

    expect(container.read(focusedScreenProvider), _screen2);
    expect(screen2.selectedIndices, [0]);
    expect(screen1.selectedIndices, isEmpty);
    expect(workspace3.selectedWindow, _windowC);
  });

  test('a meta window resolves to its shell window', () {
    bringMetaWindowIntoView(ref, 'meta-c');

    expect(workspace3.selectedWindow, _windowC);
  });

  test('a dialog resolves to its parent tile', () {
    bringWindowIntoView(ref, _dialog);

    expect(workspace3.selectedWindow, _windowC);
  });
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_label.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

const _screenId = 'screen-1';
const _windowA = PersistentWindowId('window-a');

class _FixedScreenState extends ScreenState {
  _FixedScreenState(this._screen);
  final Screen _screen;

  @override
  Screen build(ScreenId screenId) => _screen;
}

class _FixedWorkspaceState extends WorkspaceState {
  _FixedWorkspaceState(this._workspace);
  final Workspace _workspace;

  @override
  Workspace build(WorkspaceId workspaceId) => _workspace;
}

class _FixedPersistentWindowState extends PersistentWindowState {
  _FixedPersistentWindowState(this._window);
  final PersistentWindow _window;

  @override
  PersistentWindow build(PersistentWindowId windowId) => _window;
}

class _FixedLocalizedEntry extends LocalizedDesktopEntryForId {
  _FixedLocalizedEntry(this._entry);
  final LocalizedDesktopEntry? _entry;

  @override
  Future<LocalizedDesktopEntry?> build(String appId) async => _entry;
}

LocalizedDesktopEntry _entry(String name) => LocalizedDesktopEntry(
  desktopEntry: const DesktopEntry(entries: {}),
  entries: {DesktopEntryKey.name.string: name},
);

Workspace _workspace(
  String id, {
  WorkspaceCategory? category,
  List<PersistentWindowId> windows = const [],
}) => Workspace(
  workspaceId: id,
  tileableWindowList: windows.lock,
  selectedIndex: 0,
  visibleLength: 1,
  category: category,
);

Screen _screen(String? label, List<String> workspaces) => Screen(
  screenId: _screenId,
  workspaceList: workspaces.lock,
  selectedIndex: 0,
  label: label,
);

ProviderContainer _container(List<Override> overrides) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('an explicit screen label wins', () async {
    final container = _container([
      screenStateProvider(_screenId).overrideWith(
        () => _FixedScreenState(_screen('My screen', const ['ws-1'])),
      ),
    ]);

    expect(
      await container.read(screenLabelProvider(_screenId).future),
      'My screen',
    );
  });

  test('joins workspace category names', () async {
    final container = _container([
      screenStateProvider(_screenId).overrideWith(
        () => _FixedScreenState(_screen(null, const ['ws-1', 'ws-2'])),
      ),
      workspaceStateProvider('ws-1').overrideWith(
        () => _FixedWorkspaceState(
          _workspace('ws-1', category: WorkspaceCategory.Development),
        ),
      ),
      workspaceStateProvider('ws-2').overrideWith(
        () => _FixedWorkspaceState(
          _workspace('ws-2', category: WorkspaceCategory.Network),
        ),
      ),
    ]);

    expect(
      await container.read(screenLabelProvider(_screenId).future),
      'Development, Network',
    );
  });

  test('falls back to the desktop entry name of the first window', () async {
    final container = _container([
      screenStateProvider(
        _screenId,
      ).overrideWith(() => _FixedScreenState(_screen(null, const ['ws-1']))),
      workspaceStateProvider('ws-1').overrideWith(
        () =>
            _FixedWorkspaceState(_workspace('ws-1', windows: const [_windowA])),
      ),
      persistentWindowStateProvider(_windowA).overrideWith(
        () => _FixedPersistentWindowState(
          const PersistentWindow(
            windowId: _windowA,
            properties: WindowProperties(appId: 'brave'),
          ),
        ),
      ),
      localizedDesktopEntryForIdProvider(
        'brave',
      ).overrideWith(() => _FixedLocalizedEntry(_entry('Brave'))),
    ]);

    expect(
      await container.read(screenLabelProvider(_screenId).future),
      'Brave',
    );
  });

  test('returns Empty when nothing resolves', () async {
    final container = _container([
      screenStateProvider(
        _screenId,
      ).overrideWith(() => _FixedScreenState(_screen(null, const ['ws-1']))),
      workspaceStateProvider(
        'ws-1',
      ).overrideWith(() => _FixedWorkspaceState(_workspace('ws-1'))),
    ]);

    expect(
      await container.read(screenLabelProvider(_screenId).future),
      'Empty',
    );
  });
}

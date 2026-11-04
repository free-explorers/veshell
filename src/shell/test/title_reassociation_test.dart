import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';
import 'package:shell/window/provider/window_manager/matching_utils.dart';
import 'package:shell/window/provider/window_manager/windows_available_for_matching.dart';

const _meta = 'meta-code';
const _rightTile = PersistentWindowId('tile-right');
const _wrongTile = PersistentWindowId('tile-wrong');

class _FixedMetaWindowState extends MetaWindowState {
  _FixedMetaWindowState(this._window);
  final MetaWindow _window;

  @override
  MetaWindow build(String id) => _window;
}

class _FixedWindowMap extends MetaWindowWindowMap {
  _FixedWindowMap(this._entries);
  final Map<MetaWindowId, WindowId> _entries;

  @override
  IMap<MetaWindowId, WindowId> build() => _entries.toIMap();
}

class _FakePersistentWindowState extends PersistentWindowState {
  _FakePersistentWindowState(this._window);
  final PersistentWindow _window;
  final moves = <(MetaWindowId, WindowId)>[];

  @override
  PersistentWindow build(PersistentWindowId windowId) => _window;

  @override
  MatchingInfo getMatchingInfo() =>
      MatchingInfo.fromWindowProperties(_window.properties);

  @override
  void moveMetaWindowTo(
    MetaWindowId metaWindowId,
    WindowId destination, {
    required String reason,
    MatchingCost? cost,
  }) {
    moves.add((metaWindowId, destination));
  }
}

PersistentWindow _tile(PersistentWindowId id, String title) => PersistentWindow(
  windowId: id,
  properties: WindowProperties(appId: 'code-oss', title: title),
  metaWindowId: 'meta-$id',
);

void main() {
  ProviderContainer container({
    required String windowTitle,
    required String wrongTileTitle,
    required String rightTileTitle,
  }) {
    final wrongTile = _FakePersistentWindowState(
      _tile(_wrongTile, wrongTileTitle),
    );
    final rightTile = _FakePersistentWindowState(
      _tile(_rightTile, rightTileTitle),
    );
    final container = ProviderContainer(
      overrides: [
        metaWindowStateProvider(_meta).overrideWith(
          () => _FixedMetaWindowState(
            MetaWindow(
              id: _meta,
              pid: 42,
              mapped: true,
              surfaceId: 0,
              needDecoration: false,
              gameModeActivated: false,
              scaleRatio: 1,
              appId: 'code-oss',
              title: windowTitle,
            ),
          ),
        ),
        metaWindowWindowMapProvider.overrideWith(
          () => _FixedWindowMap({_meta: _wrongTile}),
        ),
        windowsAvailableForMatchingProvider.overrideWithValue([
          _wrongTile,
          _rightTile,
        ]),
        persistentWindowStateProvider(_wrongTile).overrideWith(() => wrongTile),
        persistentWindowStateProvider(_rightTile).overrideWith(() => rightTile),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a late specific title moves the window to the matching sibling', () {
    final c = container(
      windowTitle: 'Navigation2.mp4 - veshell_video - Code - OSS',
      wrongTileTitle: 'opencode - veshell - Code - OSS',
      rightTileTitle: 'opencode - veshell_video - Code - OSS',
    );
    final engine = c.read(matchingEngineProvider.notifier);

    expect(engine.reassociateMetaWindow(_meta), isTrue);
    final wrongTile =
        c.read(persistentWindowStateProvider(_wrongTile).notifier)
            as _FakePersistentWindowState;
    expect(wrongTile.moves, [(_meta, _rightTile)]);
  });

  test('a title that matches the current tile stays put', () {
    final c = container(
      windowTitle: 'opencode - veshell - Code - OSS',
      wrongTileTitle: 'opencode - veshell - Code - OSS',
      rightTileTitle: 'opencode - veshell_video - Code - OSS',
    );
    final engine = c.read(matchingEngineProvider.notifier);

    expect(engine.reassociateMetaWindow(_meta), isFalse);
    final wrongTile =
        c.read(persistentWindowStateProvider(_wrongTile).notifier)
            as _FakePersistentWindowState;
    expect(wrongTile.moves, isEmpty);
  });

  test('a generic startup title cannot move a window between tiles', () {
    final c = container(
      windowTitle: 'Code - OSS',
      wrongTileTitle: 'opencode - veshell - Code - OSS',
      rightTileTitle: 'opencode - veshell_video - Code - OSS',
    );
    final engine = c.read(matchingEngineProvider.notifier);

    expect(engine.reassociateMetaWindow(_meta), isFalse);
  });
}

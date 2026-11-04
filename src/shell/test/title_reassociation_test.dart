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
import 'package:shell/window/provider/window_manager/title_reassociation.dart';
import 'package:shell/window/provider/window_manager/windows_available_for_matching.dart';

const _meta = 'meta-code';
const _rightTile = PersistentWindowId('tile-right');
const _wrongTile = PersistentWindowId('tile-wrong');
const _otherTile = PersistentWindowId('tile-other');
final ISet<WindowId> _burst = {_wrongTile, _rightTile}.toISet();

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
    String otherTileTitle = 'unrelated - Code - OSS',
  }) {
    final otherTile = _FakePersistentWindowState(
      _tile(_otherTile, otherTileTitle),
    );
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
          _otherTile,
        ]),
        persistentWindowStateProvider(_wrongTile).overrideWith(() => wrongTile),
        persistentWindowStateProvider(_rightTile).overrideWith(() => rightTile),
        persistentWindowStateProvider(_otherTile).overrideWith(() => otherTile),
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

    expect(engine.reassociateMetaWindow(_meta, burstTiles: _burst), isTrue);
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

    expect(engine.reassociateMetaWindow(_meta, burstTiles: _burst), isFalse);
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

    expect(engine.reassociateMetaWindow(_meta, burstTiles: _burst), isFalse);
  });

  test('a tile outside the burst never receives the window', () {
    final c = container(
      windowTitle: 'Navigation2.mp4 - veshell_video - Code - OSS',
      wrongTileTitle: 'opencode - veshell - Code - OSS',
      // The burst sibling is no better than the current tile; only the tile
      // outside the burst matches.
      rightTileTitle: 'opencode - veshell - Code - OSS',
      otherTileTitle: 'opencode - veshell_video - Code - OSS',
    );
    final engine = c.read(matchingEngineProvider.notifier);

    expect(engine.reassociateMetaWindow(_meta, burstTiles: _burst), isFalse);
  });

  group('TitleReassociation', () {
    final settledAt = DateTime(2026, 11, 4, 12);

    test('a burst on a single tile registers nothing', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final pending = c.read(titleReassociationProvider.notifier)
        ..registerBurst([_meta], [_wrongTile], now: settledAt);
      expect(pending.pendingTilesFor(_meta, now: settledAt), isNull);
    });

    test('pending until expiry, measured from the settle', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final pending = c.read(titleReassociationProvider.notifier)
        ..registerBurst([_meta], _burst, now: settledAt);
      final justBefore = settledAt.add(
        const Duration(milliseconds: MAX_TITLE_REASSOCIATION_TIME_MS),
      );
      expect(pending.pendingTilesFor(_meta, now: justBefore), _burst);
      expect(
        pending.pendingTilesFor(
          _meta,
          now: justBefore.add(const Duration(milliseconds: 1)),
        ),
        isNull,
      );
    });

    test('user input ends the provisional ownership', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final pending = c.read(titleReassociationProvider.notifier)
        ..registerBurst([_meta], _burst, now: settledAt)
        ..markInteracted(_meta);
      expect(pending.pendingTilesFor(_meta, now: settledAt), isNull);
    });
  });

  test('a window on a fresh app-name tile moves to its exact sibling', () {
    // The origin was created by the launcher and only stores the desktop
    // entry name; the restored workspace title matches the sibling exactly.
    final c = container(
      windowTitle: 'opencode - veshell_video - Code - OSS',
      wrongTileTitle: 'Code - OSS',
      rightTileTitle: 'opencode - veshell_video - Code - OSS',
    );
    expect(
      c
          .read(matchingEngineProvider.notifier)
          .reassociateMetaWindow(_meta, burstTiles: _burst),
      isTrue,
    );
  });

  test('a window owned outside the burst is left alone', () {
    final c = container(
      windowTitle: 'opencode - veshell_video - Code - OSS',
      wrongTileTitle: 'opencode - veshell - Code - OSS',
      rightTileTitle: 'opencode - veshell_video - Code - OSS',
    );
    expect(
      c
          .read(matchingEngineProvider.notifier)
          .reassociateMetaWindow(
            _meta,
            burstTiles: {_rightTile, _otherTile}.toISet(),
          ),
      isFalse,
    );
  });

  group('TitleReassociation input', () {
    test('input before the settle prevents registration', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final now = DateTime(2026, 11, 4, 12);
      final pending = c.read(titleReassociationProvider.notifier)
        ..markInteracted(_meta)
        ..registerBurst([_meta], _burst, now: now);
      expect(pending.pendingTilesFor(_meta, now: now), isNull);
    });

    test('a removed window is forgotten', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final now = DateTime(2026, 11, 4, 12);
      final pending = c.read(titleReassociationProvider.notifier)
        ..markInteracted(_meta)
        ..forget(_meta)
        ..registerBurst([_meta], _burst, now: now);
      expect(pending.pendingTilesFor(_meta, now: now), _burst);
    });
  });
}

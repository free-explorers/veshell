import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/monitor/provider/monitor_placement.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_manager_state.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

// Replays a resume of Deadlock through Steam, with the windows and sizes of a
// session log and an X11 recording: Steam shows "Sign in to Steam" (700×440),
// its main window and "Launching..." (600×286) while the game's tile waits for
// its first window.

const _gameTile = PersistentWindowId('tile-deadlock');
const _otherGameTile = PersistentWindowId('tile-other-game');
const _steamTile = PersistentWindowId('tile-steam');

class _Windows extends WindowManager {
  _Windows(this._windows);
  final Set<WindowId> _windows;

  @override
  WindowManagerState build() => WindowManagerState(windows: _windows.lock);
}

class _MetaWindow extends MetaWindowState {
  _MetaWindow(this._window);
  final MetaWindow _window;

  @override
  MetaWindow build(String id) => _window;
}

class _Tile extends PersistentWindowState {
  _Tile(this._window, {this.carrier, this.waitingSince});
  final PersistentWindow _window;
  final Set<String>? carrier;
  final DateTime? waitingSince;

  @override
  PersistentWindow build(PersistentWindowId windowId) => _window;

  @override
  Set<String>? get awaitedLaunchCarrier => carrier;

  @override
  MatchingInfo getMatchingInfo() => MatchingInfo(
    appId: _window.properties.appId,
    title: _window.properties.title,
    waitingForAppSince: waitingSince,
  );
}

MetaWindow _steamWindow(
  String id,
  String title, {
  String appId = 'steamwebhelper',
  bool fixedSize = true,
  Size size = const Size(600, 286),
}) => MetaWindow(
  id: id,
  pid: 664964,
  mapped: true,
  surfaceId: 0,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
  appId: appId,
  windowClass: 'steam',
  title: title,
  isFixedSized: fixedSize,
  geometry: Offset.zero & size,
);

PersistentWindow _game(PersistentWindowId id, String steamAppId) =>
    PersistentWindow(
      windowId: id,
      properties: WindowProperties(
        appId: 'steam_app_$steamAppId',
        title: 'Deadlock',
        windowClass: 'steam_app_$steamAppId',
      ),
    );

const _steam = PersistentWindow(
  windowId: _steamTile,
  properties: WindowProperties(
    appId: 'steam',
    title: 'Steam',
    windowClass: 'steam',
  ),
  metaWindowId: 'steam-main',
);

ProviderContainer _container(
  List<MetaWindow> metaWindows, {
  bool gameWaiting = true,
  bool withOtherWaitingGame = false,
}) {
  final now = DateTime.now();
  final container = ProviderContainer(
    overrides: [
      windowManagerProvider.overrideWith(
        () => _Windows({
          _steamTile,
          _gameTile,
          if (withOtherWaitingGame) _otherGameTile,
        }),
      ),
      monitorPlacementsProvider.overrideWithValue(const []),
      for (final window in metaWindows)
        metaWindowStateProvider(
          window.id,
        ).overrideWith(() => _MetaWindow(window)),
      persistentWindowStateProvider(
        _steamTile,
      ).overrideWith(() => _Tile(_steam)),
      persistentWindowStateProvider(_gameTile).overrideWith(
        () => _Tile(
          _game(_gameTile, '1422450'),
          carrier: gameWaiting ? const {'steam'} : null,
          waitingSince: gameWaiting ? now : null,
        ),
      ),
      if (withOtherWaitingGame)
        persistentWindowStateProvider(_otherGameTile).overrideWith(
          () => _Tile(
            _game(_otherGameTile, '570'),
            carrier: const {'com.valvesoftware.Steam'},
            waitingSince: now.subtract(const Duration(seconds: 5)),
          ),
        ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('Steam\'s "Launching..." dialog goes to the game it launches', () {
    final launching = _steamWindow('launching', 'Launching...');
    final engine = _container([
      launching,
    ]).read(matchingEngineProvider.notifier);

    expect(engine.steamLaunchingDialogTileFor(launching.id), _gameTile);
  });

  test('a localized launch dialog is recognized without its title', () {
    final launching = _steamWindow('launching', 'Lancement…');
    final engine = _container([
      launching,
    ]).read(matchingEngineProvider.notifier);

    expect(engine.steamLaunchingDialogTileFor(launching.id), _gameTile);
  });

  test('only the launch dialog goes to the game, not Steam signing in', () {
    final signIn = _steamWindow(
      'sign-in',
      'Sign in to Steam',
      size: const Size(700, 440),
    );
    final engine = _container([signIn]).read(matchingEngineProvider.notifier);

    expect(engine.steamLaunchingDialogTileFor(signIn.id), isNull);
  });

  test("Steam's main window is left to Steam's tile", () {
    final main = _steamWindow(
      'main',
      'Steam',
      appId: 'steam',
      fixedSize: false,
      size: const Size(2512, 1392),
    );
    final engine = _container([main]).read(matchingEngineProvider.notifier);

    expect(engine.steamLaunchingDialogTileFor(main.id), isNull);
  });

  test('a resizable Steam window of the same size is not the dialog', () {
    final store = _steamWindow('store', 'Special Offers', fixedSize: false);
    final engine = _container([store]).read(matchingEngineProvider.notifier);

    expect(engine.steamLaunchingDialogTileFor(store.id), isNull);
  });

  test('without a launch waiting on Steam, Steam windows match as usual', () {
    final launching = _steamWindow('launching', 'Launching...');
    final engine = _container([
      launching,
    ], gameWaiting: false).read(matchingEngineProvider.notifier);

    expect(engine.steamLaunchingDialogTileFor(launching.id), isNull);
  });

  test('a game window is not taken for a Steam dialog', () {
    const game = MetaWindow(
      id: 'game',
      pid: 1,
      mapped: true,
      surfaceId: 0,
      needDecoration: false,
      gameModeActivated: false,
      scaleRatio: 1,
      appId: 'steam_app_1422450',
      windowClass: 'steam_app_1422450',
      title: 'Deadlock',
      geometry: Rect.fromLTWH(0, 0, 640, 480),
    );
    final engine = _container([game]).read(matchingEngineProvider.notifier);

    expect(engine.steamLaunchingDialogTileFor(game.id), isNull);
  });

  test('of two games waiting on Steam, the latest launch gets the dialog', () {
    final launching = _steamWindow('launching', 'Launching...');
    final engine = _container([
      launching,
    ], withOtherWaitingGame: true).read(matchingEngineProvider.notifier);

    expect(engine.steamLaunchingDialogTileFor(launching.id), _gameTile);
  });
}

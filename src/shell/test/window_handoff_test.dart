import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/systemd/provider/session_guard.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/title_reassociation.dart';
import 'package:shell/window/provider/window_manager/windows_available_for_matching.dart';

const _wrongWindow = 'meta-wrong';
const _otherWindow = 'meta-other';
const _clickedTile = PersistentWindowId('tile-clicked');
const _otherTile = PersistentWindowId('tile-other');

/// Records launches without driving `systemd`.
class _FakeAppLaunch extends AppLaunch {
  @override
  void build() {}
}

/// A meta window whose title the test can change, as the compositor's
/// property patch does; the tile listening to it drives the re-association.
class _MutableMetaWindowState extends MetaWindowState {
  _MutableMetaWindowState(this._window);

  MetaWindow _window;

  @override
  MetaWindow build(String id) => _window;

  /// Reports a new title, as the compositor's property patch would.
  void showTitle(String title) {
    _window = _window.copyWith(title: title);
    state = _window;
  }
}

/// A tile whose build does not touch the persistent store; the test seeds the
/// mixin through [initialize].
class _TestPersistentWindowState extends PersistentWindowState {
  _TestPersistentWindowState(this.initial);

  final PersistentWindow initial;

  @override
  PersistentWindow build(PersistentWindowId windowId) => initial;
}

MetaWindow _window(String id, String title) => MetaWindow(
  id: id,
  pid: 1,
  mapped: true,
  surfaceId: 0,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
  appId: 'code-oss',
  title: title,
);

PersistentWindow _tile(PersistentWindowId id, String title) => PersistentWindow(
  windowId: id,
  properties: WindowProperties(appId: 'code-oss', title: title),
);

void main() {
  test('a re-associated window hands a window back without a placeholder', () {
    final wrongWindow = _MutableMetaWindowState(
      _window(_wrongWindow, 'Code - OSS'),
    );
    final otherWindow = _MutableMetaWindowState(
      _window(_otherWindow, 'Code - OSS'),
    );
    final clickedTile = _TestPersistentWindowState(
      _tile(_clickedTile, 'zsh - veshell - Code - OSS'),
    );
    final otherTile = _TestPersistentWindowState(
      _tile(_otherTile, 'main.dart - tribu - Code - OSS'),
    );
    final container = ProviderContainer(
      overrides: [
        appLaunchProvider.overrideWith(_FakeAppLaunch.new),
        prepareForShutdownSignalsProvider.overrideWith(
          (ref) => const Stream<bool>.empty(),
        ),
        metaWindowStateProvider(_wrongWindow).overrideWith(() => wrongWindow),
        metaWindowStateProvider(_otherWindow).overrideWith(() => otherWindow),
        windowsAvailableForMatchingProvider.overrideWithValue([
          _clickedTile,
          _otherTile,
        ]),
        persistentWindowStateProvider(
          _clickedTile,
        ).overrideWith(() => clickedTile),
        persistentWindowStateProvider(_otherTile).overrideWith(() => otherTile),
      ],
    );
    addTearDown(container.dispose);
    container.listen(sessionGuardProvider, (_, _) {});

    // The burst settled: the clicked tile displays the restored window that
    // belongs to the other tile, which displays the remaining one. Both still
    // report the generic startup title (the shell keeps the specific stored
    // titles).
    container
        .read(persistentWindowStateProvider(_clickedTile).notifier)
        .initialize(
          _tile(
            _clickedTile,
            'zsh - veshell - Code - OSS',
          ).copyWith(metaWindowId: _wrongWindow),
        );
    container
        .read(persistentWindowStateProvider(_otherTile).notifier)
        .initialize(
          _tile(
            _otherTile,
            'main.dart - tribu - Code - OSS',
          ).copyWith(metaWindowId: _otherWindow),
        );
    expect(
      container.read(persistentWindowStateProvider(_clickedTile)).metaWindowId,
      _wrongWindow,
    );
    expect(
      container.read(persistentWindowStateProvider(_otherTile)).metaWindowId,
      _otherWindow,
    );

    // The burst left both windows' ownership provisional until their titles
    // settle.
    container
        .read(titleReassociationProvider.notifier)
        .registerBurst([_wrongWindow], [_clickedTile, _otherTile]);

    // The restored window reports its workspace title. It must move to the
    // tile that stores that title…
    wrongWindow.showTitle('main.dart - tribu - Code - OSS');

    // …and the destination settles at once, handing its own window back to
    // the now empty tile in the same frame. Neither tile ever displays a
    // placeholder, so no closing/opening transition plays between them.
    expect(
      container.read(persistentWindowStateProvider(_otherTile)).metaWindowId,
      _wrongWindow,
    );
    expect(
      container.read(persistentWindowStateProvider(_clickedTile)).metaWindowId,
      _otherWindow,
    );
  });
}

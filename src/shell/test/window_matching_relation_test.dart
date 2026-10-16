import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';

const _metaWindowId = 'meta-sweethome';
const _tile = PersistentWindowId('tile-sweethome');

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

MetaWindow _window({required bool isFixedSized}) => MetaWindow(
  id: _metaWindowId,
  pid: 1,
  mapped: true,
  surfaceId: 0,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
  appId: 'sweethome3d',
  title: 'Sans titre - Sweet Home 3D',
  isFixedSized: isFixedSized,
);

PersistentWindow _tileWindow({required String? displayedMetaWindowId}) =>
    PersistentWindow(
      windowId: _tile,
      properties: const WindowProperties(appId: 'sweethome3d', title: 'win0'),
      metaWindowId: displayedMetaWindowId,
    );

ProviderContainer _container({
  required bool metaWindowIsFixedSized,
  required String? displayedMetaWindowId,
}) {
  final container = ProviderContainer(
    overrides: [
      metaWindowStateProvider(_metaWindowId).overrideWith(
        () => _FixedMetaWindowState(
          _window(isFixedSized: metaWindowIsFixedSized),
        ),
      ),
      persistentWindowStateProvider(_tile).overrideWith(
        () => _FixedPersistentWindowState(
          _tileWindow(displayedMetaWindowId: displayedMetaWindowId),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // Regression for Sweet Home 3D: the launch burst settles on a transient
  // "win0" window, that window closes, and the real window opens afterwards.
  // The tracked-launch relation then resolves to the (now empty) tile; the
  // real window must become the tile's window, not a dialog of it.
  test('a settled resizable window returns to an empty owner tile', () {
    final container = _container(
      metaWindowIsFixedSized: false,
      displayedMetaWindowId: null,
    );
    final engine = container.read(matchingEngineProvider.notifier);

    expect(engine.ownerTileOwnsNoWindow(_tile), isTrue);
    expect(
      engine.relationAttachesToOwnerAsWindow(_metaWindowId, _tile),
      isTrue,
    );
  });

  test('a window does not attach to an owner tile that already owns one', () {
    final container = _container(
      metaWindowIsFixedSized: false,
      displayedMetaWindowId: 'another-window',
    );
    final engine = container.read(matchingEngineProvider.notifier);

    expect(engine.ownerTileOwnsNoWindow(_tile), isFalse);
    expect(
      engine.relationAttachesToOwnerAsWindow(_metaWindowId, _tile),
      isFalse,
    );
  });

  test('a fixed-size splash stays a dialog even on an empty owner tile', () {
    final container = _container(
      metaWindowIsFixedSized: true,
      displayedMetaWindowId: null,
    );
    final engine = container.read(matchingEngineProvider.notifier);

    expect(
      engine.relationAttachesToOwnerAsWindow(_metaWindowId, _tile),
      isFalse,
    );
  });
}

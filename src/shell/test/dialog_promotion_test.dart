import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_manager_state.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

const _tile = PersistentWindowId('tile');
const _dialogA = DialogWindowId('dialog-a');
const _dialogB = DialogWindowId('dialog-b');
const _realWindowId = 'meta-real';
const _shownWindowId = 'meta-shown';

/// The real promotion logic without the persistent-storage machinery.
class _TestWindowManager extends WindowManager {
  @override
  WindowManagerState build() => WindowManagerState(windows: <WindowId>{}.lock);
}

/// Swallows the activation patches a promoted window makes.
class _FakePlatformManager extends PlatformManager {
  @override
  Stream<PlatformEvent> build() => const Stream.empty();

  @override
  Future<void> request(PlatformRequest request) async {}
}

class _TestTileState extends PersistentWindowState {
  _TestTileState(this._window);
  final PersistentWindow _window;

  @override
  PersistentWindow build(PersistentWindowId windowId) {
    initialize(_window);
    return state;
  }
}

class _FixedDialogState extends DialogWindowState {
  _FixedDialogState(this._dialog);
  final DialogWindow _dialog;

  @override
  DialogWindow build(DialogWindowId windowId) => _dialog;
}

class _FixedMetaWindowState extends MetaWindowState {
  _FixedMetaWindowState(this._window);
  final MetaWindow _window;

  @override
  MetaWindow build(String id) => _window;
}

PersistentWindow _tileWindow() => const PersistentWindow(
  windowId: _tile,
  properties: WindowProperties(appId: 'sweethome3d', title: 'win0'),
);

MetaWindow _metaWindow({
  String? parent,
  bool isModal = false,
  bool isFixedSized = false,
  String id = _realWindowId,
}) => MetaWindow(
  id: id,
  pid: 1,
  mapped: true,
  surfaceId: 0,
  needDecoration: true,
  gameModeActivated: false,
  scaleRatio: 1,
  parent: parent,
  isModal: isModal,
  isFixedSized: isFixedSized,
);

DialogWindow _dialog(DialogWindowId id, String metaWindowId) => DialogWindow(
  windowId: id,
  properties: const WindowProperties(appId: 'sweethome3d'),
  metaWindowId: metaWindowId,
  parentWindowId: _tile,
);

void main() {
  ProviderContainer createContainer({
    MetaWindow? metaWindow,
    bool withSecondDialog = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        windowManagerProvider.overrideWith(_TestWindowManager.new),
        platformManagerProvider.overrideWith(_FakePlatformManager.new),
        persistentWindowStateProvider(
          _tile,
        ).overrideWith(() => _TestTileState(_tileWindow())),
        metaWindowStateProvider(_realWindowId).overrideWith(
          () => _FixedMetaWindowState(metaWindow ?? _metaWindow()),
        ),
        metaWindowStateProvider(_shownWindowId).overrideWith(
          () => _FixedMetaWindowState(_metaWindow(id: _shownWindowId)),
        ),
        dialogWindowStateProvider(_dialogA).overrideWith(
          () => _FixedDialogState(_dialog(_dialogA, _realWindowId)),
        ),
        dialogWindowStateProvider(_dialogB).overrideWith(
          () => _FixedDialogState(_dialog(_dialogB, 'meta-other')),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(dialogSetForWindowProvider(_tile).notifier).add(_dialogA);
    if (withSecondDialog) {
      container.read(dialogSetForWindowProvider(_tile).notifier).add(_dialogB);
    }
    return container;
  }

  String? tileDisplayed(ProviderContainer container) =>
      container.read(persistentWindowStateProvider(_tile)).metaWindowId;

  test('a sole extractable dialog is promoted to the tile', () {
    final container = createContainer();

    container
        .read(windowManagerProvider.notifier)
        .promoteSoleExtractableDialogForTile(_tile);

    expect(container.read(dialogSetForWindowProvider(_tile)), isEmpty);
    expect(tileDisplayed(container), _realWindowId);
  });

  test('a modal dialog is not promoted', () {
    final container = createContainer(metaWindow: _metaWindow(isModal: true));

    container
        .read(windowManagerProvider.notifier)
        .promoteSoleExtractableDialogForTile(_tile);

    expect(
      container.read(dialogSetForWindowProvider(_tile)),
      contains(_dialogA),
    );
    expect(tileDisplayed(container), isNull);
  });

  test('a fixed-size dialog is not promoted', () {
    final container = createContainer(
      metaWindow: _metaWindow(isFixedSized: true),
    );

    container
        .read(windowManagerProvider.notifier)
        .promoteSoleExtractableDialogForTile(_tile);

    expect(
      container.read(dialogSetForWindowProvider(_tile)),
      contains(_dialogA),
    );
    expect(tileDisplayed(container), isNull);
  });

  test('a client-parented dialog is not promoted', () {
    final container = createContainer(metaWindow: _metaWindow(parent: 'owner'));

    container
        .read(windowManagerProvider.notifier)
        .promoteSoleExtractableDialogForTile(_tile);

    expect(
      container.read(dialogSetForWindowProvider(_tile)),
      contains(_dialogA),
    );
    expect(tileDisplayed(container), isNull);
  });

  test('a tile with several dialogs is not promoted', () {
    final container = createContainer(withSecondDialog: true);

    container
        .read(windowManagerProvider.notifier)
        .promoteSoleExtractableDialogForTile(_tile);

    expect(container.read(dialogSetForWindowProvider(_tile)), hasLength(2));
    expect(tileDisplayed(container), isNull);
  });

  test(
    'a tile that loses its displayed window promotes its sole dialog',
    () async {
      final container = createContainer();
      final tile = container.read(persistentWindowStateProvider(_tile).notifier)
        ..addMetaWindow(_shownWindowId);
      expect(tileDisplayed(container), _shownWindowId);

      tile.removeMetaWindow(_shownWindowId);
      // The promotion is deferred by a microtask after the display
      // recomputation.
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(container.read(dialogSetForWindowProvider(_tile)), isEmpty);
      expect(tileDisplayed(container), _realWindowId);
    },
  );
}

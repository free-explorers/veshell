import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/window/model/dialog_area_entry.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/selected_dialog_for_window.dart';

const _parent = PersistentWindowId('parent');
const _dialogA = DialogWindowId('a');
const _dialogB = DialogWindowId('b');

class _FixedDialogState extends DialogWindowState {
  _FixedDialogState(this._dialog);
  final DialogWindow _dialog;

  @override
  DialogWindow build(DialogWindowId windowId) => _dialog;
}

class _FixedMetaWindowState extends MetaWindowState {
  _FixedMetaWindowState(this._metaWindow);
  final MetaWindow _metaWindow;

  @override
  MetaWindow build(String id) => _metaWindow;
}

MetaWindow _metaWindow(
  String id, {
  String? parent,
  bool isModal = false,
  bool isFixedSized = false,
}) => MetaWindow(
  id: id,
  pid: 1,
  mapped: true,
  surfaceId: 0,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
  parent: parent,
  isModal: isModal,
  isFixedSized: isFixedSized,
);

DialogWindow _dialog(DialogWindowId id, String metaWindowId) => DialogWindow(
  windowId: id,
  properties: const WindowProperties(appId: 'app'),
  metaWindowId: metaWindowId,
  parentWindowId: _parent,
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        dialogWindowStateProvider(
          _dialogA,
        ).overrideWith(() => _FixedDialogState(_dialog(_dialogA, 'meta-a'))),
        dialogWindowStateProvider(
          _dialogB,
        ).overrideWith(() => _FixedDialogState(_dialog(_dialogB, 'meta-b'))),
      ],
    );
    addTearDown(container.dispose);
  });

  void add(DialogWindowId id) =>
      container.read(dialogSetForWindowProvider(_parent).notifier).add(id);

  void remove(DialogWindowId id) =>
      container.read(dialogSetForWindowProvider(_parent).notifier).remove(id);

  void select(DialogAreaEntry? entry) => container
      .read(selectedDialogForWindowProvider(_parent).notifier)
      .select(entry);

  String? activationTarget() =>
      container.read(selectedDialogMetaWindowForWindowProvider(_parent));

  test('no dialogs resolves to no activation target', () {
    expect(activationTarget(), isNull);
  });

  test('the newest dialog is the default activation target', () {
    add(_dialogA);
    add(_dialogB);

    expect(activationTarget(), 'meta-b');
  });

  test('an explicit tab selection wins', () {
    add(_dialogA);
    add(_dialogB);
    select(const DialogWindowEntry(_dialogA));

    expect(activationTarget(), 'meta-a');
  });

  test('the chooser selection activates no client', () {
    add(_dialogA);
    select(const FileChooserEntry());

    expect(activationTarget(), isNull);
  });

  test('a removed selection falls back to the newest remaining dialog', () {
    add(_dialogA);
    add(_dialogB);
    select(const DialogWindowEntry(_dialogA));

    remove(_dialogA);

    expect(activationTarget(), 'meta-b');
  });

  test('a floating dialog wins the keyboard over a newer tabbed one', () {
    final local = ProviderContainer(
      overrides: [
        dialogWindowStateProvider(
          _dialogA,
        ).overrideWith(() => _FixedDialogState(_dialog(_dialogA, 'meta-a'))),
        dialogWindowStateProvider(
          _dialogB,
        ).overrideWith(() => _FixedDialogState(_dialog(_dialogB, 'meta-b'))),
        metaWindowStateProvider('meta-a').overrideWith(
          () => _FixedMetaWindowState(_metaWindow('meta-a', isModal: true)),
        ),
        metaWindowStateProvider(
          'meta-b',
        ).overrideWith(() => _FixedMetaWindowState(_metaWindow('meta-b'))),
      ],
    );
    addTearDown(local.dispose);

    local.read(dialogSetForWindowProvider(_parent).notifier).add(_dialogA);
    local.read(dialogSetForWindowProvider(_parent).notifier).add(_dialogB);

    expect(
      local.read(selectedDialogMetaWindowForWindowProvider(_parent)),
      'meta-a',
      reason: 'the modal floats on top of the newer dialog',
    );
  });

  group('isExtractableDialog', () {
    MetaWindow metaWindow({
      String? parent,
      bool isModal = false,
      bool isFixedSized = false,
    }) => MetaWindow(
      id: 'meta',
      pid: 1,
      mapped: true,
      surfaceId: 1,
      needDecoration: false,
      gameModeActivated: false,
      scaleRatio: 1,
      parent: parent,
      isModal: isModal,
      isFixedSized: isFixedSized,
    );

    test('a regular top-level window is extractable', () {
      expect(isExtractableDialog(metaWindow()), isTrue);
    });

    test('a modal dialog is not extractable', () {
      expect(isExtractableDialog(metaWindow(isModal: true)), isFalse);
    });

    test('a fixed-size dialog is not extractable', () {
      expect(isExtractableDialog(metaWindow(isFixedSized: true)), isFalse);
    });

    test('a dialog declaring a parent is not extractable', () {
      expect(isExtractableDialog(metaWindow(parent: 'owner')), isFalse);
    });
  });

  group('isFloatingDialog', () {
    test('a regular window does not float', () {
      expect(isFloatingDialog(_metaWindow('meta')), isFalse);
    });

    test('a modal dialog floats', () {
      expect(isFloatingDialog(_metaWindow('meta', isModal: true)), isTrue);
    });

    test('a fixed-size dialog floats', () {
      expect(isFloatingDialog(_metaWindow('meta', isFixedSized: true)), isTrue);
    });

    test('a dialog declaring a parent floats', () {
      // Even resizable and non-modal: the client declared it a dialog, so it is
      // not stretched into a tab (the same predicate that offers extraction).
      expect(isFloatingDialog(_metaWindow('meta', parent: 'owner')), isTrue);
    });

    test('floating and extractable are exact complements', () {
      for (final metaWindow in [
        _metaWindow('meta'),
        _metaWindow('meta', parent: 'owner'),
        _metaWindow('meta', isModal: true),
        _metaWindow('meta', isFixedSized: true),
      ]) {
        expect(isFloatingDialog(metaWindow), !isExtractableDialog(metaWindow));
      }
    });
  });
}

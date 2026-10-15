import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
}

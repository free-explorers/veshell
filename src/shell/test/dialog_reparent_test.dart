import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';

const _oldParent = PersistentWindowId('tile-old');
const _newParent = PersistentWindowId('tile-new');
const _dialog = DialogWindowId('dialog');
const _metaWindow = 'meta-window';

class _FakeDialogWindowState extends DialogWindowState {
  _FakeDialogWindowState(this._window);
  final DialogWindow _window;

  @override
  DialogWindow build(DialogWindowId windowId) => _window;

  @override
  void onCurrentlyDisplayedMetaWindowChanged(MetaWindowId? metaWindowId) {}
}

class _RecordingDialogSet extends DialogSetForWindow {
  final added = <DialogWindowId>[];
  final removed = <DialogWindowId>[];

  @override
  ISet<DialogWindowId> build(WindowId parentId) => ISet();

  @override
  void add(DialogWindowId dialogId) => added.add(dialogId);

  @override
  void remove(DialogWindowId dialogId) => removed.add(dialogId);
}

void main() {
  test('a late authoritative parent re-parents the existing dialog', () {
    final oldSet = _RecordingDialogSet();
    final newSet = _RecordingDialogSet();
    const dialog = DialogWindow(
      windowId: _dialog,
      properties: WindowProperties(appId: 'code-oss', title: 'Code - OSS'),
      metaWindowId: _metaWindow,
      parentWindowId: _oldParent,
    );
    final container = ProviderContainer(
      overrides: [
        dialogWindowStateProvider(
          _dialog,
        ).overrideWith(() => _FakeDialogWindowState(dialog)),
        dialogSetForWindowProvider(_oldParent).overrideWith(() => oldSet),
        dialogSetForWindowProvider(_newParent).overrideWith(() => newSet),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(dialogWindowStateProvider(_dialog).notifier)
        .reparent(_newParent);

    expect(
      container.read(dialogWindowStateProvider(_dialog)).parentWindowId,
      _newParent,
    );
    expect(oldSet.removed, [_dialog]);
    expect(newSet.added, [_dialog]);
  });
}

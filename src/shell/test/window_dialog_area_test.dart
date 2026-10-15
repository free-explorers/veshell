import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/widget/panel_tab.dart';
import 'package:shell/window/model/dialog_area_entry.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/selected_dialog_for_window.dart';
import 'package:shell/window/widget/window.dart';
import 'package:shell/window/widget/window_dialog_area.dart';

const _parent = PersistentWindowId('parent');
const _dialogA = DialogWindowId('a');
const _dialogB = DialogWindowId('b');

class _FixedDialogSet extends DialogSetForWindow {
  _FixedDialogSet(this._ids);
  final List<DialogWindowId> _ids;

  @override
  ISet<DialogWindowId> build(WindowId parentId) => _ids.toISet();
}

class _FixedDialogState extends DialogWindowState {
  _FixedDialogState(this._dialog);
  final DialogWindow _dialog;

  @override
  DialogWindow build(DialogWindowId windowId) => _dialog;
}

/// Keeps the tab icon lookup off the filesystem.
class _NoDesktopEntry extends LocalizedDesktopEntryForId {
  @override
  Future<LocalizedDesktopEntry?> build(String appId) async => null;
}

DialogWindow _dialog(DialogWindowId id, String metaWindowId, String title) =>
    DialogWindow(
      windowId: id,
      properties: WindowProperties(appId: 'org.example.App', title: title),
      metaWindowId: metaWindowId,
      parentWindowId: _parent,
    );

void main() {
  testWidgets('the dialog area lists every dialog and selects the newest', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWithValue(
          const Stream<PlatformEvent>.empty(),
        ),
        dialogSetForWindowProvider(
          _parent,
        ).overrideWith(() => _FixedDialogSet([_dialogA, _dialogB])),
        dialogWindowStateProvider(_dialogA).overrideWith(
          () => _FixedDialogState(_dialog(_dialogA, 'meta-a', 'Alpha')),
        ),
        dialogWindowStateProvider(_dialogB).overrideWith(
          () => _FixedDialogState(_dialog(_dialogB, 'meta-b', 'Beta')),
        ),
        localizedDesktopEntryForIdProvider(
          'org.example.App',
        ).overrideWith(_NoDesktopEntry.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: WindowDialogArea(
                parentWindowId: _parent,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // One pill per dialog, and the newest is the default selection.
    expect(find.byType(PanelTab), findsNWidgets(2));
    // The close action lives in every pill. These dialogs' meta windows are
    // untracked, so neither counts as a regular toplevel and no extract shows.
    expect(find.byIcon(MdiIcons.close), findsNWidgets(2));
    expect(find.byIcon(MdiIcons.openInNew), findsNothing);
    expect(
      container.read(selectedDialogMetaWindowForWindowProvider(_parent)),
      'meta-b',
    );
    // Only the selected dialog is mounted in the body; its meta window is
    // untracked here, so the body renders nothing but the layout still holds.
    expect(find.byType(WindowWidget), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(
      container.read(selectedDialogForWindowProvider(_parent)),
      const DialogWindowEntry(_dialogA),
    );
  });

  testWidgets('the tile content stays tappable with no dialog open', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWithValue(
          const Stream<PlatformEvent>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);

    var taps = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: WindowDialogArea(
                parentWindowId: _parent,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(WindowDialogArea));
    await tester.pump();

    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}

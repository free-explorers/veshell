import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/widget/panel_tab.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/window/model/dialog_area_entry.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/selected_dialog_for_window.dart';
import 'package:shell/window/widget/window.dart';
import 'package:shell/window/widget/window_dialog_area.dart';
import 'package:shell/window/widget/window_dialogs.dart';

const _parent = PersistentWindowId('parent');
const _dialogA = DialogWindowId('a');
const _dialogB = DialogWindowId('b');
const _modalMetaWindowId = 'meta-b';
const _modalSurfaceId = 7;

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

/// A tracked meta window for a floating dialog, with a no-op `patch` so the
/// surface's post-frame output patch does not reach the platform.
class _FixedMetaWindowState extends MetaWindowState {
  _FixedMetaWindowState(this._metaWindow);
  final MetaWindow _metaWindow;

  @override
  MetaWindow build(String id) => _metaWindow;

  @override
  Future<void> patch(
    MetaWindowPatchMessage patch, {
    bool propagate = true,
  }) async {}
}

/// The dialog surface's committed buffer, so `FloatableWindow` has a size.
class _FixedSurfaceState extends WlSurfaceState {
  @override
  WlSurface build(int surfaceId) => WlSurface(
    surfaceId: surfaceId,
    role: SurfaceRole.xdgToplevel,
    texture: const SurfaceTexture(id: 1, size: Size(320, 240)),
    scale: 1,
    subsurfacesBelow: IList(),
    subsurfacesAbove: IList(),
    inputRegion: Rect.zero,
  );
}

MetaWindow _modalMetaWindow() => const MetaWindow(
  id: _modalMetaWindowId,
  pid: 1,
  mapped: true,
  surfaceId: _modalSurfaceId,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
  isModal: true,
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

  testWidgets('a modal dialog floats instead of taking a tab', (tester) async {
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
          () =>
              _FixedDialogState(_dialog(_dialogB, _modalMetaWindowId, 'Beta')),
        ),
        metaWindowStateProvider(
          _modalMetaWindowId,
        ).overrideWith(() => _FixedMetaWindowState(_modalMetaWindow())),
        wlSurfaceStateProvider(
          _modalSurfaceId,
        ).overrideWith(_FixedSurfaceState.new),
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
            body: CurrentMonitorName(
              name: 'M1',
              child: SizedBox(
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
      ),
    );
    await tester.pumpAndSettle();

    // Only the regular dialog is a tab; the modal floats over the tile.
    expect(find.widgetWithText(PanelTab, 'Alpha'), findsOneWidget);
    expect(find.widgetWithText(PanelTab, 'Beta'), findsNothing);
    expect(find.byType(WindowDialogs), findsOneWidget);
    // The floating modal keeps the keyboard over the tabbed dialog.
    expect(
      container.read(selectedDialogMetaWindowForWindowProvider(_parent)),
      _modalMetaWindowId,
    );
    expect(tester.takeException(), isNull);
  });
}

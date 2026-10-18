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
import 'package:shell/meta_window/widget/meta_surface_decoration.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/widget/frosted_surface.dart';
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
const _floatingMetaWindowId = 'meta-b';
const _floatingSurfaceId = 7;

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
  _FixedSurfaceState(this._size);
  final Size _size;

  @override
  WlSurface build(int surfaceId) => WlSurface(
    surfaceId: surfaceId,
    role: SurfaceRole.xdgToplevel,
    texture: SurfaceTexture(id: 1, size: _size),
    scale: 1,
    subsurfacesBelow: IList(),
    subsurfacesAbove: IList(),
    inputRegion: Rect.zero,
  );
}

MetaWindow _floatingMetaWindow() => const MetaWindow(
  id: _floatingMetaWindowId,
  pid: 1,
  mapped: true,
  surfaceId: _floatingSurfaceId,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
  isModal: true,
  geometry: Rect.fromLTWH(0, 0, 320, 240),
);

/// Pumps the dialog area with a floating dialog (`Beta`) whose surface buffer is
/// [surfaceSize] over a `320x240` window geometry.
///
/// [metaWindow] defaults to a modal dialog; pass one declaring a client parent
/// to exercise a resizable, non-modal window the client still declares a
/// dialog.
Future<ProviderContainer> _pumpFloatingDialogArea(
  WidgetTester tester, {
  required Size surfaceSize,
  MetaWindow? metaWindow,
  bool settle = true,
}) async {
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
            _FixedDialogState(_dialog(_dialogB, _floatingMetaWindowId, 'Beta')),
      ),
      metaWindowStateProvider(_floatingMetaWindowId).overrideWith(
        () => _FixedMetaWindowState(metaWindow ?? _floatingMetaWindow()),
      ),
      wlSurfaceStateProvider(
        _floatingSurfaceId,
      ).overrideWith(() => _FixedSurfaceState(surfaceSize)),
      localizedDesktopEntryForIdProvider(
        'org.example.App',
      ).overrideWith(_NoDesktopEntry.new),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(_areaApp(container));
  if (settle) {
    await tester.pumpAndSettle();
  }
  return container;
}

/// The dialog area under test, sized like a maximized tile.
Widget _areaApp(ProviderContainer container) => UncontrolledProviderScope(
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
    final container = await _pumpFloatingDialogArea(
      tester,
      surfaceSize: const Size(320, 240),
    );

    // Only the regular dialog is a tab; the modal floats over the tile.
    expect(find.widgetWithText(PanelTab, 'Alpha'), findsOneWidget);
    expect(find.widgetWithText(PanelTab, 'Beta'), findsNothing);
    expect(find.byType(WindowDialogs), findsOneWidget);
    // A bare surface (buffer == geometry) gets the shell frame.
    expect(find.byType(ServerSideFrame), findsOneWidget);
    // The floating modal keeps the keyboard over the tabbed dialog.
    expect(
      container.read(selectedDialogMetaWindowForWindowProvider(_parent)),
      _floatingMetaWindowId,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a client-parented dialog floats instead of taking a tab', (
    tester,
  ) async {
    // Resizable and non-modal, but the client declared a parent: a genuine
    // dialog, so it must not be stretched into a tab (and offers no extract).
    final container = await _pumpFloatingDialogArea(
      tester,
      surfaceSize: const Size(320, 240),
      metaWindow: const MetaWindow(
        id: _floatingMetaWindowId,
        pid: 1,
        mapped: true,
        surfaceId: _floatingSurfaceId,
        needDecoration: false,
        gameModeActivated: false,
        scaleRatio: 1,
        parent: 'meta-owner',
        geometry: Rect.fromLTWH(0, 0, 320, 240),
      ),
    );

    expect(find.widgetWithText(PanelTab, 'Alpha'), findsOneWidget);
    expect(find.widgetWithText(PanelTab, 'Beta'), findsNothing);
    expect(find.byType(WindowDialogs), findsOneWidget);
    expect(
      container.read(selectedDialogMetaWindowForWindowProvider(_parent)),
      _floatingMetaWindowId,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a client-decorated dialog keeps its CSD, unframed', (
    tester,
  ) async {
    // The surface buffer is bigger than the window geometry: the client draws
    // its own shadow and rounded corners in the margins, so the shell must not
    // frame it (nor clip those margins off).
    await _pumpFloatingDialogArea(tester, surfaceSize: const Size(360, 280));

    expect(find.byType(WindowDialogs), findsOneWidget);
    expect(find.byType(ServerSideFrame), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a dialog open at mount is frosted on the first frame', (
    tester,
  ) async {
    // No settle: a tile built while a dialog is already open must come up
    // frosted, not blur in from nothing.
    await _pumpFloatingDialogArea(
      tester,
      surfaceSize: const Size(320, 240),
      settle: false,
    );

    expect(
      tester.widget<FrostedSurface>(find.byType(FrostedSurface)).blurSigma,
      greaterThan(0),
    );
    expect(find.widgetWithText(PanelTab, 'Alpha'), findsOneWidget);
  });

  testWidgets('closing keeps the panel mounted while the frost fades out', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWithValue(
          const Stream<PlatformEvent>.empty(),
        ),
        dialogWindowStateProvider(_dialogA).overrideWith(
          () => _FixedDialogState(_dialog(_dialogA, 'meta-a', 'Alpha')),
        ),
        localizedDesktopEntryForIdProvider(
          'org.example.App',
        ).overrideWith(_NoDesktopEntry.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(dialogSetForWindowProvider(_parent).notifier).add(_dialogA);

    await tester.pumpWidget(_areaApp(container));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(PanelTab, 'Alpha'), findsOneWidget);

    container
        .read(dialogSetForWindowProvider(_parent).notifier)
        .remove(_dialogA);
    // One frame into the close: the panel is still mounted, fading with the
    // backdrop, so the tile is never left frosted over an empty panel.
    await tester.pump();
    expect(find.widgetWithText(PanelTab, 'Alpha'), findsOneWidget);
    expect(
      tester.widget<FrostedSurface>(find.byType(FrostedSurface)).blurSigma,
      greaterThan(0),
    );

    // Once the ramp finishes, both are gone.
    await tester.pumpAndSettle();
    expect(find.widgetWithText(PanelTab, 'Alpha'), findsNothing);
    expect(
      tester.widget<FrostedSurface>(find.byType(FrostedSurface)).blurSigma,
      0,
    );
  });
}

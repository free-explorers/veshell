import 'dart:io';

import 'package:defer_pointer/defer_pointer.dart';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/meta_window/model/meta_popup.serializable.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_popup_for_id.dart';
import 'package:shell/meta_window/provider/meta_popup_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_popup.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/meta_window/widget/meta_surface_decoration.dart';
import 'package:shell/meta_window/widget/meta_surface_resize_handle.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/interactive_resize/interactive_resize.serializable.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/mouse_buttons_event/mouse_buttons_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/model/request/start_move_window/start_move_window.serializable.dart';
import 'package:shell/platform/model/request/start_resize_window/start_resize_window.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/settings/provider/state/hotkeys_setting.dart';
import 'package:shell/settings/provider/util/default_config_directory.dart';
import 'package:shell/shared/widget/frosted_surface.dart';
import 'package:shell/shared/widget/panel_tab.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/widget/surface.dart';
import 'package:shell/wayland/widget/surface/view_input_listener.dart';
import 'package:shell/window/model/dialog_area_entry.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/selected_dialog_for_window.dart';
import 'package:shell/window/widget/floatable_window.dart';
import 'package:shell/window/widget/floating_window_area.dart';
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

/// Records the patches a floating area sends, so the viewport publication can
/// be asserted independently of the platform channel.
class _RecordingMetaWindowState extends MetaWindowState {
  _RecordingMetaWindowState(this._metaWindow);
  MetaWindow _metaWindow;
  final List<MetaWindowPatchMessage> patches = [];

  @override
  MetaWindow build(String id) => _metaWindow;

  @override
  Future<void> patch(
    MetaWindowPatchMessage patch, {
    bool propagate = true,
  }) async {
    patches.add(patch);
    // Mirror the real notifier's state mutation: if the floating area ever
    // calls this during the build phase again, Riverpod's debug guard fails
    // the test instead of silently dropping the viewport.
    switch (patch) {
      case UpdateViewport():
        _metaWindow = _metaWindow.copyWith(viewport: patch.value);
        state = _metaWindow;
      default:
        break;
    }
  }
}

/// A meta window whose client-maximize flag can be toggled, standing in for a
/// CSD maximize/restore button.
class _MutableMetaWindowState extends MetaWindowState {
  _MutableMetaWindowState(this._metaWindow);
  MetaWindow _metaWindow;

  @override
  MetaWindow build(String id) => _metaWindow;

  void setClientMaximized({required bool value}) {
    _metaWindow = _metaWindow.copyWith(clientMaximized: value);
    state = _metaWindow;
  }

  void setPosition(Offset value) {
    _metaWindow = _metaWindow.copyWith(position: value);
    state = _metaWindow;
  }

  void setPositionExplicit(bool value) {
    _metaWindow = _metaWindow.copyWith(positionExplicit: value);
    state = _metaWindow;
  }

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
    inputRegion: Offset.zero & _size,
  );
}

class _FixedPopupSet extends MetaPopupForId {
  _FixedPopupSet(this._ids);
  final ISet<MetaPopupId> _ids;

  @override
  ISet<MetaPopupId> build(MetaWindowId parentId) => _ids;
}

class _FixedPopupState extends MetaPopupState {
  _FixedPopupState(this._popup);
  final MetaPopup _popup;

  @override
  MetaPopup build(String id) => _popup;
}

/// Accepts activation requests without a platform channel.
class _FakePlatformManager extends PlatformManager {
  static final requests = <PlatformRequest>[];

  @override
  Stream<PlatformEvent> build() => const Stream.empty();

  @override
  Future<void> request(PlatformRequest request) async {
    requests.add(request);
  }
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

/// A regular top-level dialog: the kind the dialog area would tab.
MetaWindow _regularDialogMetaWindow() => const MetaWindow(
  id: 'meta-a',
  pid: 1,
  mapped: true,
  surfaceId: 8,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
  title: 'Alpha',
  // Surface-local geometry; the output position is separate.
  geometry: Rect.fromLTWH(0, 0, 200, 150),
  // Already clamped by Rust against its tile: the shell renders the model
  // position unchanged instead of applying a second local clamp.
  position: Offset(700, 150),
);

/// The window displayed by a floating tile, positioned on the output.
MetaWindow _mainMetaWindow() => const MetaWindow(
  id: 'meta-main',
  pid: 1,
  mapped: true,
  surfaceId: 9,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
  geometry: Rect.fromLTWH(0, 0, 400, 300),
  position: Offset(665, 358),
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
      // A floating surface watches the shell shortcuts; leave them empty
      // rather than pulling in the settings tree.
      hotkeysSettingProvider.overrideWithValue(const {}),
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
  test(
    'dialog display mode keeps the tiled presentation for non-floating tiles',
    () {
      expect(
        dialogMetaWindowDisplayMode(null),
        MetaWindowDisplayMode.maximized,
      );
      expect(
        dialogMetaWindowDisplayMode(DisplayMode.maximized),
        MetaWindowDisplayMode.maximized,
      );
      expect(
        dialogMetaWindowDisplayMode(DisplayMode.fullscreen),
        MetaWindowDisplayMode.maximized,
      );
      expect(
        dialogMetaWindowDisplayMode(DisplayMode.game),
        MetaWindowDisplayMode.maximized,
      );
      expect(
        dialogMetaWindowDisplayMode(DisplayMode.floating),
        MetaWindowDisplayMode.floating,
      );
    },
  );

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
    // `needDecoration: false` means the client draws its own decoration; even
    // when its buffer equals the geometry the shell must not add a shadow.
    expect(find.byType(ServerSideFrame), findsNothing);
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

  testWidgets('a floating tile floats its window and dialogs in one stack', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWith(_FakePlatformManager.new),
        // The floating surface watches the shell shortcuts; leave them empty
        // rather than pulling in the settings tree.
        hotkeysSettingProvider.overrideWithValue(const {}),
        dialogSetForWindowProvider(
          _parent,
        ).overrideWith(() => _FixedDialogSet([_dialogA])),
        dialogWindowStateProvider(_dialogA).overrideWith(
          () => _FixedDialogState(_dialog(_dialogA, 'meta-a', 'Alpha')),
        ),
        metaWindowStateProvider('meta-a').overrideWith(
          () => _MutableMetaWindowState(_regularDialogMetaWindow()),
        ),
        metaWindowStateProvider(
          'meta-main',
        ).overrideWith(() => _FixedMetaWindowState(_mainMetaWindow())),
        // The committed buffer is taller than the reported geometry: the
        // floating box must follow the buffer so the content is not clipped.
        wlSurfaceStateProvider(
          8,
        ).overrideWith(() => _FixedSurfaceState(const Size(200, 300))),
        wlSurfaceStateProvider(
          9,
        ).overrideWith(() => _FixedSurfaceState(const Size(400, 300))),
      ],
    );
    addTearDown(container.dispose);
    final areaFocusNode = FocusNode(debugLabel: 'floating-area');
    addTearDown(areaFocusNode.dispose);

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
                child: FloatingWindowArea(
                  parentWindowId: _parent,
                  mainMetaWindowId: 'meta-main',
                  background: const SizedBox.expand(),
                  focusNode: areaFocusNode,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No dialog area and no tab bar: the displayed window and the regular
    // top-level are both independently framed floatables.
    expect(find.byType(WindowDialogArea), findsNothing);
    expect(find.byType(PanelTab), findsNothing);
    // The floating stack builds the FloatableWindow siblings directly; it does
    // not reuse the dialog-area container.
    expect(find.byType(WindowDialogs), findsNothing);
    expect(find.byType(FloatableWindow), findsNWidgets(2));
    // Both windows are client-decorated (`needDecoration: false`): they keep
    // their own frames and the shell must not add a second backdrop shadow.
    expect(find.byType(ServerSideFrame), findsNothing);

    // The displayed window sits at the bottom, the dialog above it.
    List<MetaWindowId> stackOrder() => tester
        .widgetList<FloatableWindow>(find.byType(FloatableWindow))
        .map((window) => window.metaWindowId)
        .toList();
    expect(stackOrder(), ['meta-main', 'meta-a']);

    // Floating resize handles use the historical outside placement. The
    // `DeferredPointerHandler` inside `WithResizeHandles` makes them reachable
    // beyond the exact-size window `Positioned`, including the resize cursor.
    final floatingHandles = tester
        .widgetList<WithResizeHandles>(find.byType(WithResizeHandles))
        .toList();
    expect(floatingHandles.every((handles) => !handles.inside), isTrue);
    expect(floatingHandles, isNotEmpty);
    // Handles only request the compositor gesture; they never resize locally.
    expect(
      floatingHandles.every((handles) => handles.onResizeStart != null),
      isTrue,
    );
    _FakePlatformManager.requests.clear();
    floatingHandles.first.onResizeStart!(ResizeEdge.bottomRight);
    await tester.pump();
    final resizeRequest = _FakePlatformManager.requests
        .whereType<StartResizeWindowRequest>()
        .single;
    expect(
      (resizeRequest.message as StartResizeWindowMessage).edge,
      ResizeEdge.bottomRight,
    );

    // The dialog keeps the placement its client asked for, relative to the
    // displayed window, instead of being centred in the tile.
    final tileRect = tester.getRect(find.byType(FloatingWindowArea));
    final mainRect = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is FloatableWindow && widget.metaWindowId == 'meta-main',
      ),
    );
    final dialogRect = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is FloatableWindow && widget.metaWindowId == 'meta-a',
      ),
    );
    final mainHandlesRect = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is WithResizeHandles && widget.metaWindowId == 'meta-main',
      ),
    );
    // The handle widget keeps the window's exact box. Its outside handles are
    // deferred children, not part of the layout bounds.
    expect(mainHandlesRect, mainRect);

    // The outside handle is reachable beyond the window box through the
    // deferred pointer handler inherited from the v0.1.4 layout.
    _FakePlatformManager.requests.clear();
    final leftHandle = find.byWidgetPredicate(
      (widget) =>
          widget is ResizeHandle &&
          widget.metaWindowId == 'meta-main' &&
          widget.resizeEdge == ResizeEdge.left,
    );
    final leftHandleRect = tester.getRect(leftHandle);
    expect(leftHandleRect.right, closeTo(mainRect.left, 0.5));
    await tester.dragFrom(leftHandleRect.center, const Offset(-20, 0));
    await tester.pump();
    final outsideResize = _FakePlatformManager.requests
        .whereType<StartResizeWindowRequest>()
        .single;
    expect(
      (outsideResize.message as StartResizeWindowMessage).edge,
      ResizeEdge.left,
    );
    // Rust owns placement clamping. Flutter renders the model position as-is;
    // applying a second clamp here would fight a compositor move/resize.
    expect(
      mainRect.left,
      closeTo(tileRect.left + _mainMetaWindow().position!.dx, 0.5),
    );
    expect(
      mainRect.top,
      closeTo(tileRect.top + _mainMetaWindow().position!.dy, 0.5),
    );

    // The dialog position was clamped by Rust before it reached the shell.
    expect(dialogRect.topLeft.dx, closeTo(tileRect.left + 700, 0.5));
    expect(dialogRect.topLeft.dy, closeTo(tileRect.top + 150, 0.5));
    // The buffer is 300 high while geometry says 150; the window shows the
    // full buffer immediately instead of waiting for the next configure.
    expect(dialogRect.height, closeTo(300, 0.5));

    // The task bar lists both windows; the CSD maximize request fills the
    // window area without changing the tile's mode.
    expect(find.text('Alpha'), findsOneWidget);
    final dialogState =
        container.read(metaWindowStateProvider('meta-a').notifier)
            as _MutableMetaWindowState;
    dialogState.setClientMaximized(value: true);
    await tester.pump();

    Rect dialogWindowRect() => tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is FloatableWindow && widget.metaWindowId == 'meta-a',
      ),
    );

    final maximizedRect = dialogWindowRect();
    expect(maximizedRect.left, closeTo(tileRect.left, 0.5));
    expect(maximizedRect.top, closeTo(tileRect.top, 0.5));
    expect(maximizedRect.width, closeTo(tileRect.width, 0.5));
    expect(maximizedRect.height, closeTo(tileRect.height - 36, 0.5));

    // A CSD restore request puts the window back to its client placement.
    dialogState.setClientMaximized(value: false);
    await tester.pump();
    expect(dialogWindowRect(), dialogRect);

    // The task bar itself does not follow the paint stack: raising a window
    // must not move the entry under the pointer.
    const mainTaskKey = ValueKey('floating-taskbar-meta-main');
    const dialogTaskKey = ValueKey('floating-taskbar-meta-a');
    final mainTaskBefore = tester.getTopLeft(find.byKey(mainTaskKey));
    final dialogTaskBefore = tester.getTopLeft(find.byKey(dialogTaskKey));

    // A press on the visible part of the displayed window raises it above the
    // dialog, like clicking a window in a floating compositor.
    await tester.tapAt(Offset(mainRect.left + 20, mainRect.center.dy));
    await tester.pump();

    expect(stackOrder(), ['meta-a', 'meta-main']);
    expect(tester.getTopLeft(find.byKey(mainTaskKey)), mainTaskBefore);
    expect(tester.getTopLeft(find.byKey(dialogTaskKey)), dialogTaskBefore);
    // Focusing a floating window keeps the tile's focus node in the workspace
    // focus tree, so navigation shortcuts resolve there.
    expect(areaFocusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the displayed window stays below floating dialogs', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWith(_FakePlatformManager.new),
        hotkeysSettingProvider.overrideWithValue(const {}),
        dialogSetForWindowProvider(
          _parent,
        ).overrideWith(() => _FixedDialogSet([_dialogA])),
        dialogWindowStateProvider(_dialogA).overrideWith(
          () => _FixedDialogState(_dialog(_dialogA, 'meta-a', 'Alpha')),
        ),
        metaWindowStateProvider(
          'meta-a',
        ).overrideWith(() => _FixedMetaWindowState(_regularDialogMetaWindow())),
        metaWindowStateProvider(
          'meta-main',
        ).overrideWith(() => _FixedMetaWindowState(_mainMetaWindow())),
        wlSurfaceStateProvider(
          8,
        ).overrideWith(() => _FixedSurfaceState(const Size(200, 150))),
        wlSurfaceStateProvider(
          9,
        ).overrideWith(() => _FixedSurfaceState(const Size(400, 300))),
      ],
    );
    addTearDown(container.dispose);

    Widget area({required String? mainMetaWindowId}) =>
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
                  child: FloatingWindowArea(
                    parentWindowId: _parent,
                    mainMetaWindowId: mainMetaWindowId,
                    background: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        );

    // The dialog exists before the tile has chosen the window it displays.
    await tester.pumpWidget(area(mainMetaWindowId: null));
    await tester.pumpAndSettle();
    expect(find.byType(FloatableWindow), findsOneWidget);

    // When the displayed window appears later, it is the base layer, not a
    // newly opened window raised over the dialog.
    await tester.pumpWidget(area(mainMetaWindowId: 'meta-main'));
    await tester.pumpAndSettle();
    final stackOrder = tester
        .widgetList<FloatableWindow>(find.byType(FloatableWindow))
        .map((window) => window.metaWindowId)
        .toList();
    expect(stackOrder, ['meta-main', 'meta-a']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a title-bar drag starts a compositor move and follows it 1:1', (
    tester,
  ) async {
    _FakePlatformManager.requests.clear();
    final windowState = _MutableMetaWindowState(
      _mainMetaWindow().copyWith(
        needDecoration: true,
        position: const Offset(100, 100),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWith(_FakePlatformManager.new),
        hotkeysSettingProvider.overrideWithValue(const {}),
        dialogSetForWindowProvider(
          _parent,
        ).overrideWith(() => _FixedDialogSet([])),
        metaWindowStateProvider('meta-main').overrideWith(() => windowState),
        wlSurfaceStateProvider(
          9,
        ).overrideWith(() => _FixedSurfaceState(const Size(400, 300))),
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
                child: FloatingWindowArea(
                  parentWindowId: _parent,
                  mainMetaWindowId: 'meta-main',
                  background: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = tester.getTopLeft(find.byType(FloatableWindow));
    // Server-decorated floating windows use the same compositor resize path:
    // their handle must request the gesture rather than resize locally.
    expect(
      tester
          .widget<WithResizeHandles>(find.byType(WithResizeHandles))
          .onResizeStart,
      isNotNull,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(WindowTitleBar)),
    );
    await tester.pump();

    // The floating tile does not translate its Flutter box locally: it asks
    // the compositor to own the move, so the native X11 window and the pointer
    // basis stay in the same space.
    expect(
      _FakePlatformManager.requests.whereType<StartMoveWindowRequest>(),
      isNotEmpty,
    );
    await gesture.moveBy(const Offset(50, 25));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(FloatableWindow)), before);

    // The compositor reports the new native position; the box follows it 1:1.
    windowState.setPosition(const Offset(150, 125));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.byType(FloatableWindow));
    expect(after.dx - before.dx, closeTo(50, 1));
    expect(after.dy - before.dy, closeTo(25, 1));

    // A second move keeps the 1:1 relationship (no accumulated drift).
    windowState.setPosition(const Offset(200, 150));
    await tester.pumpAndSettle();
    final afterSecond = tester.getTopLeft(find.byType(FloatableWindow));
    expect(afterSecond.dx - before.dx, closeTo(100, 1));
    expect(afterSecond.dy - before.dy, closeTo(50, 1));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a floating position is translated from the tile global origin', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWith(_FakePlatformManager.new),
        hotkeysSettingProvider.overrideWithValue(const {}),
        dialogSetForWindowProvider(
          _parent,
        ).overrideWith(() => _FixedDialogSet([])),
        metaWindowStateProvider('meta-main').overrideWith(
          () => _FixedMetaWindowState(
            _mainMetaWindow().copyWith(position: const Offset(200, 150)),
          ),
        ),
        wlSurfaceStateProvider(
          9,
        ).overrideWith(() => _FixedSurfaceState(const Size(400, 300))),
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
              child: Padding(
                padding: const EdgeInsets.only(left: 120, top: 80),
                child: SizedBox(
                  width: 1000,
                  height: 800,
                  child: FloatingWindowArea(
                    parentWindowId: _parent,
                    mainMetaWindowId: 'meta-main',
                    background: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // X11 reports the client in compositor-global coordinates. The tile starts
    // at (120, 80); the shell must subtract that origin, not reinterpret the
    // root position as a tile-local one.
    expect(
      tester.getTopLeft(find.byType(FloatableWindow)),
      const Offset(200, 150),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dialog overlay keeps its local 1:1 drag', (tester) async {
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWith(_FakePlatformManager.new),
        hotkeysSettingProvider.overrideWithValue(const {}),
        metaWindowStateProvider(_floatingMetaWindowId).overrideWith(
          () => _FixedMetaWindowState(
            _floatingMetaWindow().copyWith(needDecoration: true),
          ),
        ),
        wlSurfaceStateProvider(
          _floatingSurfaceId,
        ).overrideWith(() => _FixedSurfaceState(const Size(320, 240))),
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
                child: WindowDialogs(metaWindowIds: [_floatingMetaWindowId]),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = tester.getTopLeft(find.byType(FloatableWindow));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(WindowTitleBar)),
    );
    await gesture.moveBy(const Offset(50, 25));
    await tester.pump();
    await gesture.moveBy(const Offset(50, 25));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.byType(FloatableWindow));

    // The dialog area is a Flutter overlay, not a native floating window:
    // its drag must remain local and 1:1.
    expect(after.dx - before.dx, closeTo(100, 1));
    expect(after.dy - before.dy, closeTo(50, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an unplaced floating window is centred, an explicit zero is kept',
    (tester) async {
      final windowState = _MutableMetaWindowState(
        _mainMetaWindow().copyWith(
          position: Offset.zero,
          positionExplicit: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          platformManagerProvider.overrideWith(_FakePlatformManager.new),
          hotkeysSettingProvider.overrideWithValue(const {}),
          dialogSetForWindowProvider(
            _parent,
          ).overrideWith(() => _FixedDialogSet([])),
          metaWindowStateProvider('meta-main').overrideWith(() => windowState),
          wlSurfaceStateProvider(
            9,
          ).overrideWith(() => _FixedSurfaceState(const Size(400, 300))),
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
                  child: FloatingWindowArea(
                    parentWindowId: _parent,
                    mainMetaWindowId: 'meta-main',
                    background: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The legacy launch configure gives X11 windows (0,0). Without an explicit
      // client placement, the floating stack centres the window.
      final centred = tester.getTopLeft(find.byType(FloatableWindow));
      expect(centred.dx, greaterThan(0));
      expect(centred.dy, greaterThan(0));

      // An explicit (0,0) placement is a real position: the window stays at the
      // tile origin instead of being centred.
      windowState.setPositionExplicit(true);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(FloatableWindow)), Offset.zero);
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets('a floating tile publishes its viewport after the frame', (
    tester,
  ) async {
    final mainState = _RecordingMetaWindowState(_mainMetaWindow());
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWith(_FakePlatformManager.new),
        hotkeysSettingProvider.overrideWithValue(const {}),
        dialogSetForWindowProvider(
          _parent,
        ).overrideWith(() => _FixedDialogSet(const [])),
        metaWindowStateProvider('meta-main').overrideWith(() => mainState),
        wlSurfaceStateProvider(
          9,
        ).overrideWith(() => _FixedSurfaceState(const Size(400, 300))),
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
                child: FloatingWindowArea(
                  parentWindowId: _parent,
                  mainMetaWindowId: 'meta-main',
                  background: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The old effect modified the provider during the build phase; Riverpod
    // threw and the compositor never received a viewport. The patch must be
    // observable after the post-frame callback runs.
    final viewportPatches = mainState.patches
        .whereType<UpdateViewport>()
        .toList();
    expect(viewportPatches, isNotEmpty);
    expect(viewportPatches.last.value, isNotNull);
    expect(viewportPatches.last.origin, isNotNull);
  });

  testWidgets('an unplaced floating window leaves initial placement to Rust', (
    tester,
  ) async {
    final mainState = _RecordingMetaWindowState(
      _mainMetaWindow().copyWith(position: null, positionExplicit: false),
    );
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWith(_FakePlatformManager.new),
        hotkeysSettingProvider.overrideWithValue(const {}),
        dialogSetForWindowProvider(
          _parent,
        ).overrideWith(() => _FixedDialogSet(const [])),
        metaWindowStateProvider('meta-main').overrideWith(() => mainState),
        wlSurfaceStateProvider(
          9,
        ).overrideWith(() => _FixedSurfaceState(const Size(400, 300))),
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
                child: FloatingWindowArea(
                  parentWindowId: _parent,
                  mainMetaWindowId: 'meta-main',
                  background: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initial placement is compositor-owned: the shell publishes the measured
    // viewport, Rust centres the window for both X11 and Wayland. Flutter must
    // not publish its own first rect, which would be a second placement
    // authority and would race the model patch.
    final rectPatches = mainState.patches.whereType<SetWindowRect>().toList();
    expect(rectPatches, isEmpty);
  });

  testWidgets('a popup in a tile overlay uses its parent box origin', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        metaPopupStateProvider('meta-popup').overrideWith(
          () => _FixedPopupState(
            const MetaPopup(
              id: 'meta-popup',
              parent: 'meta-main',
              surfaceId: 10,
              scaleRatio: 1,
              position: Offset(36, 40),
              geometry: Rect.fromLTWH(0, 0, 100, 50),
            ),
          ),
        ),
        wlSurfaceStateProvider(
          10,
        ).overrideWith(() => _FixedSurfaceState(const Size(100, 50))),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CurrentMonitorName(
                name: 'M1',
                child: DeferredPointerHandler(
                  child: Stack(
                    children: [
                      MetaPopupWidget(
                        metaPopupId: 'meta-popup',
                        parentOrigin: Offset(48, 48),
                        coordinateOffset: Offset(48, 48),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(SurfaceWidget)), const Offset(36, 40));
  });

  testWidgets('a floating Wayland surface reports its buffer origin', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWith(_FakePlatformManager.new),
        hotkeysSettingProvider.overrideWithValue(const {}),
        defaultConfigDirectoryProvider.overrideWithValue(Directory('/tmp')),
        metaWindowStateProvider('meta-main').overrideWith(
          () => _FixedMetaWindowState(
            _mainMetaWindow().copyWith(
              displayMode: MetaWindowDisplayMode.floating,
              position: const Offset(48, 48),
              // Firefox's CSD shadow margin: the window box starts at
              // (48,48), but the surface buffer starts 24x21 further up-left.
              geometry: const Rect.fromLTWH(24, 21, 400, 300),
            ),
          ),
        ),
        metaPopupForIdProvider(
          'meta-main',
        ).overrideWith(() => _FixedPopupSet(const <MetaPopupId>{}.toISet())),
        wlSurfaceStateProvider(
          9,
        ).overrideWith(() => _FixedSurfaceState(const Size(400, 300))),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 300,
                child: CurrentMonitorName(
                  name: 'M1',
                  child: MetaSurfaceWidget(
                    metaWindowId: 'meta-main',
                    decorated: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final listener = tester.widget<ViewInputListener>(
      find.byType(ViewInputListener),
    );
    expect(listener.globalOffsetOverride, const Offset(24, 27));
  });

  testWidgets('a popup is hit-tested above its parent surface', (tester) async {
    final focusNode = FocusNode(debugLabel: 'popup-hit-test');
    addTearDown(focusNode.dispose);
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWith(_FakePlatformManager.new),
        hotkeysSettingProvider.overrideWithValue(const {}),
        defaultConfigDirectoryProvider.overrideWithValue(Directory('/tmp')),
        metaWindowStateProvider(
          'meta-main',
        ).overrideWith(() => _FixedMetaWindowState(_mainMetaWindow())),
        metaPopupForIdProvider('meta-main').overrideWith(
          () => _FixedPopupSet(<MetaPopupId>{'meta-popup'}.toISet()),
        ),
        metaPopupStateProvider('meta-popup').overrideWith(
          () => _FixedPopupState(
            const MetaPopup(
              id: 'meta-popup',
              parent: 'meta-main',
              surfaceId: 10,
              scaleRatio: 1,
              position: Offset(100, 50),
              geometry: Rect.fromLTWH(0, 0, 100, 100),
            ),
          ),
        ),
        wlSurfaceStateProvider(
          9,
        ).overrideWith(() => _FixedSurfaceState(const Size(400, 300))),
        wlSurfaceStateProvider(
          10,
        ).overrideWith(() => _FixedSurfaceState(const Size(100, 100))),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 300,
                child: CurrentMonitorName(
                  name: 'M1',
                  child: MetaSurfaceWidget(
                    metaWindowId: 'meta-main',
                    decorated: false,
                    focusNode: focusNode,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MetaPopupWidget), findsOneWidget);
    expect(find.byType(SurfaceWidget), findsNWidgets(2));
    // The popup is painted after the parent and covers (100,50)-(200,150).
    await tester.tap(
      find.byType(MetaPopupWidget),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    final buttons = _FakePlatformManager.requests
        .whereType<MouseButtonsEventRequest>()
        .toList();
    expect(buttons, isNotEmpty);
    expect((buttons.last.message as MouseButtonsEventMessage).surfaceId, 10);
  });
}

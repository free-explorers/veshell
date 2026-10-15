import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/window/model/ephemeral_window.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/widget/ephemeral_window.dart';

const _windowId = EphemeralWindowId('e1');
const _metaWindowId = 'window-1';
const _surfaceId = 0;
const _surfaceSize = Size(1000, 800);

/// An ephemeral window whose launch has not produced a native surface yet.
class _WaitingWindowState extends EphemeralWindowState {
  @override
  EphemeralWindow build(EphemeralWindowId windowId) => EphemeralWindow(
    windowId: windowId,
    properties: const WindowProperties(appId: 'org.example.App'),
    screenId: 'screen-1',
  );
}

/// An ephemeral window whose native surface has been matched.
class _DisplayedWindowState extends EphemeralWindowState {
  @override
  EphemeralWindow build(EphemeralWindowId windowId) => EphemeralWindow(
    windowId: windowId,
    properties: const WindowProperties(appId: 'org.example.App'),
    screenId: 'screen-1',
    metaWindowId: _metaWindowId,
  );
}

class _FakeMetaWindowState extends MetaWindowState {
  @override
  MetaWindow build(String id) => const MetaWindow(
    id: _metaWindowId,
    pid: 1,
    mapped: true,
    surfaceId: _surfaceId,
    needDecoration: false,
    gameModeActivated: false,
    scaleRatio: 1,
    geometry: Rect.fromLTWH(0, 0, 1000, 800),
  );
}

class _FakeSurfaceState extends WlSurfaceState {
  @override
  WlSurface build(int surfaceId) => WlSurface(
    surfaceId: _surfaceId,
    role: SurfaceRole.xdgToplevel,
    texture: const SurfaceTexture(id: 1, size: _surfaceSize),
    scale: 1,
    subsurfacesBelow: IList(),
    subsurfacesAbove: IList(),
    inputRegion: Rect.zero,
  );
}

/// Swallows the activation requests the window makes when it takes focus, so
/// the test does not need a platform channel.
class _FakePlatformManager extends PlatformManager {
  @override
  Stream<PlatformEvent> build() => const Stream.empty();

  @override
  Future<void> request(PlatformRequest request) async {}
}

/// The two focus nodes the test watches: the stand-in search pane, and the
/// node handed to the ephemeral window.
typedef _FocusNodes = ({FocusNode search, FocusNode window});

void main() {
  Future<_FocusNodes> pumpWindow(
    WidgetTester tester, {
    required EphemeralWindowState Function() windowState,
    required bool displayed,
  }) async {
    final nodes = (
      search: FocusNode(debugLabel: 'search'),
      window: FocusNode(debugLabel: 'window'),
    );
    addTearDown(nodes.search.dispose);
    addTearDown(nodes.window.dispose);
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(1000, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformManagerProvider.overrideWith(_FakePlatformManager.new),
          ephemeralWindowStateProvider(_windowId).overrideWith(windowState),
          if (displayed) ...[
            metaWindowStateProvider(
              _metaWindowId,
            ).overrideWith(_FakeMetaWindowState.new),
            wlSurfaceStateProvider(
              _surfaceId,
            ).overrideWith(_FakeSurfaceState.new),
          ],
        ],
        child: MaterialApp(
          home: CurrentMonitorName(
            name: 'M1',
            child: Column(
              children: [
                // Stands in for the overview's search pane, which autofocuses
                // and keeps the keyboard until the window is shown.
                Focus(
                  focusNode: nodes.search,
                  autofocus: true,
                  child: const SizedBox(),
                ),
                Expanded(
                  child: EphemeralWindowWidget(
                    windowId: _windowId,
                    focusNode: nodes.window,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Let the autofocus and the widget's focus hand-off settle. (Not
    // `pumpAndSettle`: the waiting placeholder shows an indeterminate
    // progress indicator, which never settles.)
    await tester.pump();
    await tester.pump();
    return nodes;
  }

  testWidgets(
    'the waiting placeholder takes the keyboard while there is no surface',
    (tester) async {
      final nodes = await pumpWindow(
        tester,
        windowState: _WaitingWindowState.new,
        displayed: false,
      );

      expect(
        nodes.search.hasFocus,
        isFalse,
        reason: 'the search pane must not keep Enter while the app launches',
      );
      expect(
        nodes.window.hasFocus,
        isFalse,
        reason: 'there is no surface node yet',
      );
    },
  );

  testWidgets('the surface takes the keyboard once the window is matched', (
    tester,
  ) async {
    final nodes = await pumpWindow(
      tester,
      windowState: _DisplayedWindowState.new,
      displayed: true,
    );

    expect(
      nodes.window.hasFocus,
      isTrue,
      reason: 'the client surface owns the keyboard so Enter reaches it',
    );
    expect(nodes.search.hasFocus, isFalse);
  });
}

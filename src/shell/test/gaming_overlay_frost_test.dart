import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface_gaming_overlay.dart';
import 'package:shell/monitor/provider/monitor_placement.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/widget/frosted_surface.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

const _windowId = 'window-1';
const _surfaceId = 0;

/// A tracked, placed game window with a no-op `patch`, so the overlay's
/// post-frame geometry and display-mode patches stay off the platform.
class _FixedMetaWindowState extends MetaWindowState {
  @override
  MetaWindow build(String id) => const MetaWindow(
    id: _windowId,
    pid: 1,
    mapped: true,
    surfaceId: _surfaceId,
    needDecoration: false,
    gameModeActivated: false,
    scaleRatio: 1,
    geometry: Rect.fromLTWH(0, 0, 800, 600),
  );

  @override
  Future<void> patch(
    MetaWindowPatchMessage patch, {
    bool propagate = true,
  }) async {}
}

/// The game surface's committed buffer, so the overlay has a surface to blur.
class _FixedSurfaceState extends WlSurfaceState {
  @override
  WlSurface build(int surfaceId) => WlSurface(
    surfaceId: surfaceId,
    role: SurfaceRole.xdgToplevel,
    texture: const SurfaceTexture(id: 1, size: Size(800, 600)),
    scale: 1,
    subsurfacesBelow: IList(),
    subsurfacesAbove: IList(),
    inputRegion: Rect.zero,
  );
}

void main() {
  testWidgets('the paused game is frosted instead of dimmed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformManagerProvider.overrideWithValue(
            const Stream<PlatformEvent>.empty(),
          ),
          metaWindowStateProvider(
            _windowId,
          ).overrideWith(_FixedMetaWindowState.new),
          wlSurfaceStateProvider(
            _surfaceId,
          ).overrideWith(_FixedSurfaceState.new),
          monitorLogicalSizeForNameProvider(
            'M1',
          ).overrideWithValue(const Size(800, 600)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CurrentMonitorName(
            name: 'M1',
            child: Center(
              child: SizedBox(
                width: 800,
                height: 600,
                child: MetaSurfaceGamingOverlay(metaWindowId: _windowId),
              ),
            ),
          ),
        ),
      ),
    );

    // A game starts paused, and the frost animates in over 300ms.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final frosted = tester.widget<FrostedSurface>(find.byType(FrostedSurface));
    expect(frosted.blurSigma, greaterThan(0));
    expect(frosted.tint, isNotNull);
    // The flat dim is gone: the whole tile is tappable without its box.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == Colors.black38,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

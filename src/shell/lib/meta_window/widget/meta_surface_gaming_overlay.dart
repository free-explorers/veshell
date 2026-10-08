import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_gaming_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/monitor/provider/monitor_placement.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:uuid/uuid.dart';

class MetaSurfaceGamingOverlay extends HookConsumerWidget {
  const MetaSurfaceGamingOverlay({required this.metaWindowId, super.key});
  final String metaWindowId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaWindowState = ref.watch(metaWindowStateProvider(metaWindowId));
    // Keeps the gaming-state provider alive while the tile owns the overlay,
    // so a pause survives a route push/pop and resets when the tile leaves
    // gaming mode.
    final gamingStatus = ref.watch(metaWindowGamingStateProvider(metaWindowId));
    final paused = gamingStatus == MetaWindowGamingStatus.paused;
    final heroUuid = useMemoized(() => const Uuid().v4(), []);
    // The route currently zoomed in, if any. Owning it here makes a second tap
    // during the flight a no-op instead of stacking routes.
    final zoomRoute = useRef<Route<void>?>(null);

    final monitorName = CurrentMonitorName.of(context);

    // The fullscreen configure must carry the monitor's *logical* size (the
    // physical mode divided by its fractional scale), exactly like the
    // arrangement canvas. Using the physical mode directly desyncs the tile on
    // a scaled monitor.
    final logicalMonitorSize = ref.watch(
      monitorLogicalSizeForNameProvider(monitorName),
    );

    final zoomToGamingMode = useCallback(() {
      if (zoomRoute.value != null) return;
      ref
          .read(metaWindowGamingStateProvider(metaWindowId).notifier)
          .set(MetaWindowGamingStatus.running);

      final route = PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, _, __) => _GamingZoomRoute(
          metaWindowId: metaWindowId,
          heroUuid: heroUuid,
          monitorName: monitorName,
        ),
      );
      zoomRoute.value = route;
      Navigator.of(context, rootNavigator: true).push(route).whenComplete(() {
        zoomRoute.value = null;
      });
    }, [metaWindowId]);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (!context.mounted) return;
        final geometry = ref.read(
          metaWindowStateProvider(
            metaWindowId,
          ).select((value) => value.geometry),
        );
        final size =
            ref.read(monitorLogicalSizeForNameProvider(monitorName)) ??
            geometry?.size;

        if (geometry != null &&
            size != null &&
            size.width > 0 &&
            size.height > 0) {
          ref
              .read(metaWindowStateProvider(metaWindowId).notifier)
              .patch(
                UpdateGeometry(
                  id: metaWindowId,
                  value: Rect.fromLTWH(
                    geometry.left,
                    geometry.top,
                    size.width,
                    size.height,
                  ),
                ),
              );
        }
        // Go fullscreen only after the resize: the configure that carries the
        // fullscreen state must already have the monitor size, because
        // Chromium latches the size from that configure.
        ref
            .read(metaWindowStateProvider(metaWindowId).notifier)
            .patch(
              UpdateDisplayMode(
                id: metaWindowId,
                value: MetaWindowDisplayMode.fullscreen,
              ),
            );
        // Deliberately no auto-zoom: a game stays paused (instructions visible)
        // until the user resumes it, so merely navigating to the tile never
        // grabs the input.
      });
      return null;
    }, [metaWindowId]);

    final fallbackSize =
        (logicalMonitorSize != null && logicalMonitorSize.width > 0)
        ? logicalMonitorSize
        : const Size(1, 1);
    final surfaceSize = metaWindowState.geometry?.size ?? fallbackSize;

    return Stack(
      children: [
        Positioned.fill(
          child: Hero(
            tag: heroUuid,
            child: _SizedSurface(
              size: surfaceSize,
              child: MetaSurfaceWidget(
                metaWindowId: metaWindowId,
                decorated: false,
              ),
            ),
          ),
        ),
        // The scrim (dim + instructions) fades with the zoom: opacity follows
        // the paused/running state, so starting a game lifts the dim while the
        // hero flies, and pausing brings it back.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !paused,
            child: AnimatedOpacity(
              opacity: paused ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: GestureDetector(
                onTap: zoomToGamingMode,
                child: ColoredBox(
                  color: Colors.black38,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.gamingPaused,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.gamingModeDescription,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              context.l10n.clickToEnter,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.exitGamingHint,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The pushed fullscreen route a game tile zooms into.
///
/// Activation is driven by the route's own transition, not by the Hero
/// shuttle: a skipped transition, a missing source Hero or an accessibility
/// "reduce motion" setting would otherwise leave the compositor ungathered.
class _GamingZoomRoute extends HookConsumerWidget {
  const _GamingZoomRoute({
    required this.metaWindowId,
    required this.heroUuid,
    required this.monitorName,
  });
  final String metaWindowId;
  final String heroUuid;
  final String monitorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geometry = ref.watch(
      metaWindowStateProvider(metaWindowId).select((value) => value.geometry),
    );

    ref.listen(
      metaWindowStateProvider(
        metaWindowId,
      ).select((value) => value.gameModeActivated),
      (previous, next) {
        if (next == false) {
          Navigator.of(context).pop();
          ref
              .read(metaWindowGamingStateProvider(metaWindowId).notifier)
              .set(MetaWindowGamingStatus.paused);
        }
      },
    );

    // The route (and the Hero flight, which rebuilds the destination inside the
    // navigator's overlay) is outside the monitor's `CurrentMonitorName`, so
    // re-provide it: `MetaSurfaceWidget` reads it to report the output.
    return CurrentMonitorName(
      name: monitorName,
      child: GamingActivationTrigger(
        metaWindowId: metaWindowId,
        child: Hero(
          tag: heroUuid,
          flightShuttleBuilder:
              (
                flightContext,
                animation,
                flightDirection,
                fromContext,
                toContext,
              ) => Stack(
                fit: StackFit.expand,
                children: [
                  CurrentMonitorName(
                    name: monitorName,
                    child: _SizedSurface(
                      size: geometry?.size,
                      child: toContext.widget,
                    ),
                  ),
                  // The dim travels with the hero and fades over the transition,
                  // so it is visible while the surface zooms (a plain sibling
                  // scrim would sit under the route and be hidden).
                  FadeTransition(
                    opacity: ReverseAnimation(animation),
                    child: const ColoredBox(color: Colors.black38),
                  ),
                ],
              ),
          child: MetaSurfaceWidget(
            metaWindowId: metaWindowId,
            decorated: false,
          ),
        ),
      ),
    );
  }
}

/// Emits `UpdateGameModeActivated(true)` once the enclosing route's transition
/// settles.
///
/// Activation is deliberately tied to the route's own animation instead of a
/// Hero flight: a skipped transition, a route without a matching source Hero or
/// an accessibility "reduce motion" setting would otherwise leave the
/// compositor ungathered.
class GamingActivationTrigger extends HookConsumerWidget {
  const GamingActivationTrigger({
    required this.metaWindowId,
    required this.child,
    super.key,
  });

  final String metaWindowId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    final activated = useRef(false);
    useEffect(() {
      if (route == null || animation == null) return null;

      void onStatus(AnimationStatus status) {
        if (status != AnimationStatus.completed || activated.value) return;
        // Flutter's hero measurement briefly takes the route offstage, which
        // swaps its animation for `kAlwaysCompleteAnimation` for one frame.
        // That is not the end of the transition; activating there would grab
        // the input and cover the still-running hero flight with the native
        // render. Wait for the real completion.
        if (route.offstage) return;
        activated.value = true;
        // flutter_hooks runs `useEffect` during build and `addStatusListener`
        // can notify synchronously, so writing the provider here would be a
        // "modify a provider while building" error. Defer it past the frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ref
              .read(metaWindowStateProvider(metaWindowId).notifier)
              .patch(UpdateGameModeActivated(id: metaWindowId, value: true));
        });
      }

      animation.addStatusListener(onStatus);
      // `addStatusListener` does not replay a status already reached (for
      // example when animations are disabled and the route settles
      // instantly).
      if (animation.status == AnimationStatus.completed && !route.offstage) {
        onStatus(AnimationStatus.completed);
      }
      return () => animation.removeStatusListener(onStatus);
    }, [animation, route]);
    return child;
  }
}

/// Sizes [child] to the window's logical geometry for a Hero flight.
///
/// The size is optional so an unplaced window (no geometry yet) renders
/// without a fixed box instead of asserting.
class _SizedSurface extends StatelessWidget {
  const _SizedSurface({required this.child, this.size});
  final Widget child;
  final Size? size;

  @override
  Widget build(BuildContext context) {
    final size = this.size;
    if (size == null || size.width <= 0 || size.height <= 0) {
      return child;
    }
    return FittedBox(
      child: SizedBox(width: size.width, height: size.height, child: child),
    );
  }
}

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/meta_window/provider/meta_window_gaming_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/monitor/provider/monitor_arrangement.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/settings/model/types/monitor_setting.serializable.dart';
import 'package:shell/settings/provider/state/monitor_setting_state.dart';
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
    ref.watch(metaWindowGamingStateProvider(metaWindowId));
    final heroUuid = useMemoized(() => const Uuid().v4(), []);
    // The route currently zoomed in, if any. Owning it here makes a second tap
    // during the flight a no-op instead of stacking routes.
    final zoomRoute = useRef<Route<void>?>(null);

    final monitorName = CurrentMonitorName.of(context);

    // The fullscreen configure must carry the monitor's *logical* size (the
    // physical mode divided by its fractional scale), exactly like the
    // arrangement canvas. Using the physical mode directly desyncs the tile on
    // a scaled monitor.
    final monitor = ref.watch(monitorByNameProvider(monitorName));
    final monitorSetting = ref.watch(monitorSettingStateProvider(monitorName));
    final logicalMonitorSize = monitor == null
        ? null
        : monitorLogicalSize(
            monitor,
            monitorSetting.fractionnalScale,
            transposed: monitorSetting.transform.isTransposed,
          );

    final zoomToGamingMode = useCallback(() {
      if (zoomRoute.value != null) return;
      ref
          .read(metaWindowGamingStateProvider(metaWindowId).notifier)
          .set(MetaWindowGamingStatus.running);

      final route = PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, _, __) =>
            _GamingZoomRoute(metaWindowId: metaWindowId, heroUuid: heroUuid),
      );
      zoomRoute.value = route;
      Navigator.of(context, rootNavigator: true).push(route).whenComplete(() {
        zoomRoute.value = null;
      });
    }, [metaWindowId]);

    useEffect(() {
      final metaWindowGamingState = ref.read(
        metaWindowGamingStateProvider(metaWindowId),
      );
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (!context.mounted) return;
        final monitor = ref.read(monitorByNameProvider(monitorName));
        final monitorSetting = ref.read(
          monitorSettingStateProvider(monitorName),
        );
        final geometry = ref.read(
          metaWindowStateProvider(
            metaWindowId,
          ).select((value) => value.geometry),
        );
        final size = monitor == null
            ? geometry?.size
            : monitorLogicalSize(
                monitor,
                monitorSetting.fractionnalScale,
                transposed: monitorSetting.transform.isTransposed,
              );

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
        if (metaWindowGamingState == MetaWindowGamingStatus.running &&
            !ref
                .read(metaWindowStateProvider(metaWindowId))
                .gameModeActivated) {
          zoomToGamingMode();
        }
      });
      return null;
    }, const []);

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
        if (metaWindowState.gameModeActivated == false) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: zoomToGamingMode,
              child: ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 16,
                      children: [
                        Text(
                          context.l10n.gamingPaused,
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          context.l10n.clickToResume,
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          context.l10n.exitGamingHint,
                          style: const TextStyle(
                            color: Colors.white70,
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
        ],
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
  const _GamingZoomRoute({required this.metaWindowId, required this.heroUuid});
  final String metaWindowId;
  final String heroUuid;

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

    return GamingActivationTrigger(
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
            ) => _SizedSurface(size: geometry?.size, child: toContext.widget),
        child: MetaSurfaceWidget(metaWindowId: metaWindowId, decorated: false),
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
    final animation = ModalRoute.of(context)?.animation;
    useEffect(() {
      if (animation == null) return null;

      void onStatus(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        ref
            .read(metaWindowStateProvider(metaWindowId).notifier)
            .patch(UpdateGameModeActivated(id: metaWindowId, value: true));
      }

      animation.addStatusListener(onStatus);
      // `addStatusListener` does not replay a status already reached (for
      // example when animations are disabled and the route settles
      // instantly).
      if (animation.status == AnimationStatus.completed) {
        onStatus(AnimationStatus.completed);
      }
      return () => animation.removeStatusListener(onStatus);
    }, [animation]);
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

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/meta_window/widget/meta_surface_gaming_overlay.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

/// How long the pointer and the keyboard must stay idle before a fullscreen
/// client in a maximized tile covers its whole monitor.
const immersiveFullscreenIdleDelay = Duration(seconds: 3);

/// The zoom between the tile and the monitor, both ways.
const immersiveFullscreenTransitionDuration = Duration(milliseconds: 300);

/// Zooms a fullscreen client out of its tile onto the whole monitor once the
/// input has been idle for [idleDelay], and back into the tile on the next
/// pointer or key event.
///
/// Unlike gaming mode the surface stays drawn by Flutter and the input keeps
/// flowing through the shell: the zoom is a non-opaque route over the
/// monitor's panels that grows a second view of the surface from the tile's
/// bounds (the render box of [context]) to the monitor. The tile itself stays
/// mounted underneath — a `Hero` would unmount its focus node during the
/// return flight — and the route never takes the keyboard
/// (`requestFocus: false`), so the tile's focus node keeps driving the client
/// throughout, and the event that ends the zoom still reaches it.
///
/// Returns whether the window is (or is zooming) out of its tile: its host
/// must then stop sizing the window to the tile, since the route sizes it to
/// the monitor.
bool useImmersiveFullscreen(
  BuildContext context, {
  required bool enabled,
  required MetaWindowId metaWindowId,
  Duration idleDelay = immersiveFullscreenIdleDelay,
}) {
  final immersive = useState(false);
  final route = useRef<Route<void>?>(null);
  // Nullable: a host outside any monitor (a test, a detached preview) has no
  // monitor to cover.
  final monitorName = context
      .dependOnInheritedWidgetOfExactType<CurrentMonitorName>()
      ?.name;
  final disableAnimations = MediaQuery.disableAnimationsOf(context);
  final active = enabled && monitorName != null;

  useEffect(() {
    if (!active) {
      return null;
    }
    Timer? timer;

    void enter() {
      if (route.value != null || !context.mounted) {
        return;
      }
      final navigator = Navigator.of(context, rootNavigator: true);
      // Where the tile sits in the navigator, measured again for the return
      // zoom: the tile can have moved while the window covered the monitor.
      Rect? tileRect() {
        final tile = context.mounted ? context.findRenderObject() : null;
        final overlay = navigator.context.findRenderObject();
        if (tile is! RenderBox ||
            !tile.hasSize ||
            !tile.attached ||
            overlay is! RenderBox) {
          return null;
        }
        return MatrixUtils.transformRect(
          tile.getTransformTo(overlay),
          Offset.zero & tile.size,
        );
      }

      final duration = disableAnimations
          ? Duration.zero
          : immersiveFullscreenTransitionDuration;
      final newRoute = PageRouteBuilder<void>(
        opaque: false,
        requestFocus: false,
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        pageBuilder: (context, animation, _) => _ImmersiveFullscreenPage(
          metaWindowId: metaWindowId,
          monitorName: monitorName,
          animation: animation,
          tileRect: tileRect,
        ),
      );
      geometryLog.info('immersive fullscreen enter id=$metaWindowId');
      route.value = newRoute;
      immersive.value = true;
      unawaited(
        navigator.push(newRoute).whenComplete(() {
          if (route.value != newRoute) {
            return;
          }
          // Popped by someone else (the navigator was cleared).
          route.value = null;
          if (context.mounted) {
            immersive.value = false;
          }
        }),
      );
    }

    void leave() {
      final current = route.value;
      if (current == null) {
        return;
      }
      geometryLog.info('immersive fullscreen leave id=$metaWindowId');
      route.value = null;
      immersive.value = false;
      _dismiss(current);
    }

    void onActivity() {
      timer?.cancel();
      leave();
      timer = Timer(idleDelay, enter);
    }

    void onPointer(PointerEvent event) {
      // A device appearing or going is not the user acting.
      if (event is PointerAddedEvent || event is PointerRemovedEvent) {
        return;
      }
      onActivity();
    }

    bool onKey(KeyEvent event) {
      onActivity();
      // Only observed: the key still goes wherever it was going.
      return false;
    }

    GestureBinding.instance.pointerRouter.addGlobalRoute(onPointer);
    HardwareKeyboard.instance.addHandler(onKey);
    timer = Timer(idleDelay, enter);

    return () {
      timer?.cancel();
      GestureBinding.instance.pointerRouter.removeGlobalRoute(onPointer);
      HardwareKeyboard.instance.removeHandler(onKey);
      final current = route.value;
      if (current == null) {
        return;
      }
      route.value = null;
      // The cleanup runs while the tree is building or unmounting: neither
      // the navigator nor this hook's state may change before the frame ends.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dismiss(current);
        if (context.mounted) {
          immersive.value = false;
        }
      });
    };
  }, [active, monitorName, metaWindowId, idleDelay]);

  return active && immersive.value;
}

/// Zooms [route] back into its tile, or drops it when another route covers it.
void _dismiss(Route<void> route) {
  final navigator = route.navigator;
  if (navigator == null || !route.isActive) {
    return;
  }
  if (route.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(route);
  }
}

/// The surface out of its tile, growing from the tile onto the monitor.
class _ImmersiveFullscreenPage extends HookWidget {
  const _ImmersiveFullscreenPage({
    required this.metaWindowId,
    required this.monitorName,
    required this.animation,
    required this.tileRect,
  });

  final MetaWindowId metaWindowId;
  final String monitorName;
  final Animation<double> animation;
  final Rect? Function() tileRect;

  @override
  Widget build(BuildContext context) {
    final curved = useMemoized(
      () => CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      ),
      [animation],
    );
    useEffect(() => curved.dispose, [curved]);
    // The tile's bounds, measured once per direction: as the zoom starts, and
    // again as it turns back (the tile can have moved in between).
    final from = useRef<Rect?>(null);
    useEffect(() {
      from.value = tileRect();
      void onStatus(AnimationStatus status) {
        if (status == AnimationStatus.reverse) {
          from.value = tileRect() ?? from.value;
        }
      }

      animation.addStatusListener(onStatus);
      return () => animation.removeStatusListener(onStatus);
    }, [animation]);

    // The route is outside the monitor's `CurrentMonitorName`: re-provide it,
    // `MetaSurfaceWidget` reports the output.
    return CurrentMonitorName(
      name: monitorName,
      // Never a focus target: the tile's focus node keeps the keyboard.
      child: ExcludeFocus(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final monitor = Offset.zero & constraints.biggest;
            // Built once: the animation only moves it.
            final surface = _MonitorSizedSurface(
              metaWindowId: metaWindowId,
              target: constraints.biggest,
              routeAnimation: animation,
            );
            return AnimatedBuilder(
              animation: curved,
              builder: (context, child) {
                final t = curved.value;
                final rect = Rect.lerp(from.value ?? monitor, monitor, t)!;
                return Stack(
                  children: [
                    // The panels fade out behind the surface while it grows
                    // over them, and the bars a client leaves outside its
                    // buffer stay black.
                    Positioned.fill(
                      child: Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: const ColoredBox(color: Colors.black),
                      ),
                    ),
                    Positioned.fromRect(rect: rect, child: child!),
                  ],
                );
              },
              child: surface,
            );
          },
        ),
      ),
    );
  }
}

/// Configures the window to [target], the monitor's logical size, and shows
/// it scaled into whatever box it is laid out in, so a buffer still at the
/// tile size (or already at the monitor size) fills the zoom without being
/// cropped.
class _MonitorSizedSurface extends HookConsumerWidget {
  const _MonitorSizedSurface({
    required this.metaWindowId,
    required this.target,
    required this.routeAnimation,
  });

  final MetaWindowId metaWindowId;
  final Size target;

  /// The route's transition: the monitor sizes the window only while the
  /// route is coming in or open. Once it zooms back the tile owns the size
  /// again, and asserting the monitor size against it would bounce the client
  /// between both sizes for the whole return zoom.
  final Animation<double> routeAnimation;

  bool get _ownsSize => routeAnimation.status.isForwardOrCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MetaWindow window;
    try {
      window = ref.watch(metaWindowStateProvider(metaWindowId));
    } on Object {
      // The window is gone; its tile dismisses the route.
      return const SizedBox.shrink();
    }
    final (bufferSize, bufferScale, viewportSize) = ref.watch(
      wlSurfaceStateProvider(window.surfaceId).select(
        (value) => (value.texture?.size, value.scale, value.viewportSize),
      ),
    );
    final windowSize = bufferSize == null
        ? null
        : surfaceLogicalSize(
            bufferSize,
            bufferScale,
            window.scaleRatio,
            viewportSize: viewportSize,
          );

    // The monitor owns the window's size while it covers it, the way the tile
    // does otherwise (see `window.dart`): one correction per (target, actual)
    // pair, so a client refusing the size cannot loop. Measured on the
    // committed buffer, which is what the client actually renders.
    final lastCorrectedMismatch = useRef<(Size, Size?)?>(null);
    final isFixedSized = window.isFixedSized;
    useEffect(() {
      if (!_ownsSize ||
          isFixedSized ||
          target.width <= 0 ||
          target.height <= 0) {
        return null;
      }
      final atTarget =
          windowSize != null &&
          (windowSize.width - target.width).abs() < 1 &&
          (windowSize.height - target.height).abs() < 1;
      if (atTarget) {
        lastCorrectedMismatch.value = null;
        return null;
      }
      final mismatchKey = (target, windowSize);
      if (lastCorrectedMismatch.value == mismatchKey) {
        return null;
      }
      lastCorrectedMismatch.value = mismatchKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // The zoom back can start between the frame and this callback.
        if (!context.mounted || !_ownsSize) {
          return;
        }
        final MetaWindow current;
        try {
          current = ref.read(metaWindowStateProvider(metaWindowId));
        } on Object {
          return;
        }
        final geometry = current.geometry;
        geometryLog.info(
          'sizing immersive id=$metaWindowId '
          'target=${target.width}x${target.height} '
          'actual=${windowSize?.width}x${windowSize?.height}',
        );
        unawaited(
          ref
              .read(metaWindowStateProvider(metaWindowId).notifier)
              .patch(
                UpdateGeometry(
                  id: metaWindowId,
                  value: Rect.fromLTWH(
                    geometry?.left ?? 0,
                    geometry?.top ?? 0,
                    target.width,
                    target.height,
                  ),
                ),
              ),
        );
      });
      return null;
    }, [target, windowSize, isFixedSized]);

    // Fitted by what the client committed, not by the size just requested:
    // until the client follows the configure, its tile-sized buffer fills the
    // zoom's first frames exactly where the tile showed it.
    return FittedWindowSurface(
      size: windowSize ?? window.geometry?.size,
      child: MetaSurfaceWidget(metaWindowId: metaWindowId, decorated: false),
    );
  }
}

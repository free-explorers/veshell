import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/tile_grab/model/tile_drop.dart';
import 'package:shell/tile_grab/model/tile_grab.dart';
import 'package:shell/tile_grab/provider/tile_grab_controller.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/widget/window_placeholder.dart';

/// Scale of a pressed tile that has not popped off its slot yet.
const _pressedScale = 0.97;

/// Scale bounds of a lifted tile: a small tile shrinks a little, a
/// screen-sized one enough to see the drop targets beneath it.
const _maxLiftedScale = 0.75;
const _minLiftedScale = 0.35;

/// Longest side, in logical pixels, a lifted tile aims for.
const _liftedExtent = 720.0;

/// How much of the pointer travel a stuck tile follows before it pops off.
const _magnetStretch = 0.3;

const _popDuration = Duration(milliseconds: 280);

double _liftedScale(Size tileSize) => (_liftedExtent / tileSize.longestSide)
    .clamp(_minLiftedScale, _maxLiftedScale);

/// Draws the held tile itself, as it looked in its slot, lifted under the
/// pointer.
///
/// On press the tile is pushed in, then stays stuck to its slot like a magnet,
/// only stretching towards the pointer. Once the pointer pulls past
/// [tileGrabLiftThreshold] it snaps off: it shrinks with a slight overshoot,
/// rises, and from then on tracks the pointer exactly. The tile is scaled
/// around the spot it was grabbed at, so it never jumps away from the pointer.
///
/// Once released it flies into the gap opened for it (or into a workspace
/// button, or back home) and settles flush, over [tileGrabSettleDuration].
///
/// Every monitor view hosts one, so a tile straddling two monitors is drawn on
/// both. [origin] is this view's origin in compositor-global coordinates.
class TileGrabPreview extends HookConsumerWidget {
  const TileGrabPreview({required this.origin, super.key});

  final Offset origin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grab = ref.watch(tileGrabControllerProvider);
    final isHeld = grab != null;
    final isLifted = grab?.lifted ?? false;
    final isSettling = grab?.settling ?? false;
    final pop = useAnimationController(duration: _popDuration);
    useEffect(() {
      if (isLifted) {
        pop.forward();
      } else {
        pop.value = 0;
      }
      return null;
    }, [isHeld, isLifted]);
    final flight = useAnimationController(duration: tileGrabSettleDuration);
    useEffect(() {
      if (isSettling) {
        flight.forward(from: 0);
      } else {
        flight.value = 0;
      }
      return null;
    }, [isHeld, isSettling]);
    final popProgress = useAnimation(pop);
    final flightProgress = useAnimation(flight);

    if (grab == null || grab.tileSize.isEmpty) return const SizedBox.shrink();
    final lift = Curves.easeOutCubic.transform(popProgress);
    final land = Curves.easeInOutCubic.transform(flightProgress);
    final held = _heldRect(grab, popProgress);
    final rect = grab.settling
        ? Rect.lerp(held, grab.landingRect ?? grab.originRect, land)!
        : held;
    // It rises as it pops off and lands flush in its slot.
    final flush = 1 - land;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: rect.shift(-origin),
            child: _TileFace(
              windowId: grab.windowId,
              layoutSize: tileFlightLayoutSize(grab, land),
              windowSize: grab.tileSize,
              elevation: lerpDouble(2, 16, lift)! * flush,
              radius: lerpDouble(4, 16, lift)! * flush,
            ),
          ),
        ],
      ),
    );
  }

  /// Where the tile is drawn while held, in global coordinates.
  static Rect _heldRect(TileGrab grab, double popProgress) {
    // The overshoot is the magnet letting go; the travel itself settles
    // without one so the tile never swings past the pointer.
    final snap = Curves.easeOutBack.transform(popProgress);
    final settle = Curves.easeOutCubic.transform(popProgress);
    final scale = lerpDouble(_pressedScale, _liftedScale(grab.tileSize), snap)!;
    final stuckAt =
        grab.pressPosition +
        (grab.globalPosition - grab.pressPosition) * _magnetStretch;
    final pointer = Offset.lerp(stuckAt, grab.globalPosition, settle)!;
    final size = grab.tileSize * max(scale, 0);
    return pointer -
            Offset(
              grab.grabAnchor.dx * size.width,
              grab.grabAnchor.dy * size.height,
            ) &
        size;
  }
}

/// The size the flying tile's content is laid out at, [land] of the way
/// through its flight (`0` while it is held).
///
/// The content grows or shrinks to the size of the slot it lands in, so the
/// tile reshapes on its way there instead of being scaled with its old
/// proportions. Landing on a workspace button, it only scales down: the
/// content is not meant to be laid out that small.
@visibleForTesting
Size tileFlightLayoutSize(TileGrab grab, double land) {
  final landing = grab.landingRect;
  if (!grab.settling || landing == null || grab.target is! TileSlotTarget) {
    return grab.tileSize;
  }
  return Size.lerp(grab.tileSize, landing.size, land)!;
}

/// The tile as it is shown in its slot: its window's live buffer, or the
/// placeholder itself when no window is displayed.
///
/// The content is laid out at [layoutSize] and only then scaled to the tile's
/// rect, so a responsive placeholder looks exactly as it does in a slot of
/// that size. A window keeps its own [windowSize], anchored top-left, like a
/// tile shows it until the client resizes to its new slot.
class _TileFace extends ConsumerWidget {
  const _TileFace({
    required this.windowId,
    required this.layoutSize,
    required this.windowSize,
    required this.elevation,
    required this.radius,
  });

  final PersistentWindowId windowId;
  final Size layoutSize;
  final Size windowSize;
  final double elevation;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(persistentWindowStateProvider(windowId));
    // A copy for display only: it must neither take focus nor launch.
    final placeholder = ExcludeFocus(
      child: WindowPlaceholder(isSelected: true, window: window),
    );
    final metaWindowId = window.metaWindowId;
    return Material(
      elevation: elevation,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      // The rect and the layout size reshape together, so filling distorts
      // by a fraction of a pixel at most.
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox.fromSize(
          size: layoutSize,
          child: metaWindowId == null
              ? placeholder
              : OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: windowSize.width,
                  maxWidth: windowSize.width,
                  minHeight: windowSize.height,
                  maxHeight: windowSize.height,
                  child: _LiveWindow(
                    metaWindowId: metaWindowId,
                    fallback: placeholder,
                  ),
                ),
        ),
      ),
    );
  }
}

/// The window's current buffer, fitted into the tile. Only the texture is
/// drawn: a second `SurfaceWidget` would also report input and render origins
/// for the surface and confuse the compositor.
class _LiveWindow extends ConsumerWidget {
  const _LiveWindow({required this.metaWindowId, required this.fallback});

  final MetaWindowId metaWindowId;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A tile can briefly outlive its window; see `WindowWidget`.
    int? surfaceId;
    try {
      surfaceId = ref.watch(
        metaWindowStateProvider(metaWindowId).select((w) => w.surfaceId),
      );
    } on Object {
      surfaceId = null;
    }
    final texture = surfaceId == null
        ? null
        : ref.watch(wlSurfaceStateProvider(surfaceId).select((s) => s.texture));
    if (texture == null || texture.size.isEmpty) return fallback;
    return FittedBox(
      child: SizedBox.fromSize(
        size: texture.size,
        child: Texture(textureId: texture.id),
      ),
    );
  }
}

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/saturation_filter.dart';
import 'package:shell/tile_grab/model/tile_drop.dart';
import 'package:shell/tile_grab/provider/tile_grab_controller.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/provider/launch_morphs.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/launch_morph.dart';

/// How long a tile takes to slide to a new slot.
const _slideDuration = Duration(milliseconds: 240);

/// How the launcher moves aside for a launched tile, over the launch morph:
/// it holds still while the launched item lifts out of it as a card, then
/// slides away, arriving as the card lands.
const _launchSlideCurve = Interval(0.35, 1, curve: Curves.easeInOutCubic);

/// How much a removed tile darkens as the tile taking its slot covers it.
const tileRemovalDim = 2.0;

/// Width of the bar marking where a held tile would be inserted.
const _insertionBarWidth = 4.0;

/// The tile slot [index] of [workspaceId], shown where the tiles slide to.
///
/// While a tile is held over a workspace showing several tiles, the others
/// slide aside to open a gap where it would land, and close the gap it left
/// (see [tileDisplayIndex]). A workspace showing a single tile keeps its tiles
/// put while the tile is held, since a gap would empty it, and marks the edge
/// the tile would be inserted at with a bar instead; once the tile is
/// released, the gap opens and the shown tile slides out to make room for it.
/// The held tile's own slot is left empty: `TileGrabPreview` draws the tile
/// meanwhile.
///
/// The slot animates its absolute position, in slots, rather than an offset
/// from its index: when the drop is committed and the slot changes index, the
/// tile is already shown where it now belongs and does not move. For the same
/// reason a reorder from the keyboard slides too. The slot must be keyed by
/// its window so it keeps that position when its index changes.
class TileDropSlot extends HookConsumerWidget {
  const TileDropSlot({
    required this.workspaceId,
    required this.index,
    required this.child,
    this.windowId,
    this.initialDisplayIndex,
    this.leaving,
    super.key,
  });

  final WorkspaceId workspaceId;
  final int index;

  /// The window shown in the slot; `null` for the application launcher.
  final PersistentWindowId? windowId;

  /// The slot this tile was shown at before the window list changed, used
  /// as the starting point of a slot that has no position to carry over.
  ///
  /// A page that was off screen is not built: without this, a tile pulled
  /// into a vacated slot would be created at its new index and jump in.
  final double? initialDisplayIndex;

  /// The face of a tile removed from this slot, drawn in place beneath the
  /// tile now in it, darkening as that tile slides over it, until covered.
  ///
  /// It must be keyed: once a key has been covered, it is not drawn again.
  final Widget? leaving;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (heldWindowId, target, mark, isSettling) = ref.watch(
      tileGrabControllerProvider.select(
        (grab) => (
          grab?.windowId,
          grab?.target,
          grab?.insertionMark,
          grab?.settling ?? false,
        ),
      ),
    );
    final (windowList, visibleLength) = ref.watch(
      workspaceStateProvider(
        workspaceId,
      ).select((w) => (w.tileableWindowList, w.visibleLength)),
    );
    // The launcher also slides when a launched tile takes its place, even in
    // a workspace showing a single tile: it moves aside under the new tile.
    final slides =
        tileRowOpensGap(visibleLength, settling: isSettling) ||
        windowId == null;
    final displayIndex = tileDisplayIndex(
      workspaceId: workspaceId,
      windowList: windowList,
      index: index,
      heldWindowId: heldWindowId,
      target: target,
      opensGap: slides,
    ).toDouble();
    final isHeld = windowId != null && windowId == heldWindowId;
    // The launcher is moving aside for a tile launched from it.
    final makesWayForLaunch =
        windowId == null &&
        ref.watch(
          launchMorphsProvider.select(
            (morphs) => windowList.any(morphs.containsKey),
          ),
        );
    final position = useAnimationController(
      lowerBound: double.negativeInfinity,
      upperBound: double.infinity,
      initialValue: initialDisplayIndex ?? displayIndex,
      duration: _slideDuration,
    );
    useEffect(() {
      // The hidden held slot follows invisibly. Every other change of slot
      // slides, even with a single tile shown: the next tile pulled into a
      // vacated slot moves over it instead of jumping into place.
      if (isHeld) {
        position.value = displayIndex;
      } else if (makesWayForLaunch) {
        position.animateTo(
          displayIndex,
          duration: launchMorphDuration,
          curve: _launchSlideCurve,
        );
      } else {
        position.animateTo(displayIndex, curve: Curves.easeOutCubic);
      }
      return null;
    }, [displayIndex]);
    final shownAt = useAnimation(position);
    // How far the tile still is from covering its slot, in slots.
    final uncovered = (shownAt - index).abs().clamp(0.0, 1.0);
    final coveredLeaving = useRef<Key?>(null);
    final leaving = this.leaving;
    if (uncovered == 0) coveredLeaving.value = leaving?.key;
    final showsLeaving = leaving != null && coveredLeaving.value != leaving.key;
    final insertsAfter =
        !isSettling &&
            mark != null &&
            mark.workspaceId == workspaceId &&
            mark.index == index
        ? mark.after
        : null;
    return Stack(
      fit: StackFit.expand,
      // The page that slides is clipped by the row's viewport, as before; a
      // per-slot clip would hide it until it crossed the slot's edge.
      clipBehavior: Clip.none,
      children: [
        // A removed tile stays where it was while the tile now in its slot
        // slides over it, so it is not translated with that tile.
        if (showsLeaving)
          SaturationFilter(
            key: const ValueKey('tile-removal-dim'),
            saturation: 1,
            brightness:
                1 - tileRemovalDim * Curves.easeIn.transform(1 - uncovered),
            child: leaving,
          ),
        FractionalTranslation(
          translation: Offset(shownAt - index, 0),
          child: IgnorePointer(
            ignoring: isHeld,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(opacity: isHeld ? 0 : 1, child: child),
                if (insertsAfter != null)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: insertsAfter ? null : 0,
                    right: insertsAfter ? 0 : null,
                    width: _insertionBarWidth,
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

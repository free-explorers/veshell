import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/tile_grab/model/tile_drop.dart';
import 'package:shell/tile_grab/provider/tile_grab_controller.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

/// How long a tile takes to slide to a new slot.
const _slideDuration = Duration(milliseconds: 240);

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
    super.key,
  });

  final WorkspaceId workspaceId;
  final int index;

  /// The window shown in the slot; `null` for the application launcher.
  final PersistentWindowId? windowId;
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
    final slides = tileRowOpensGap(visibleLength, settling: isSettling);
    final displayIndex = tileDisplayIndex(
      workspaceId: workspaceId,
      windowList: windowList,
      index: index,
      heldWindowId: heldWindowId,
      target: target,
      opensGap: slides,
    ).toDouble();
    final isHeld = windowId != null && windowId == heldWindowId;
    final position = useAnimationController(
      lowerBound: double.negativeInfinity,
      upperBound: double.infinity,
      initialValue: displayIndex,
      duration: _slideDuration,
    );
    useEffect(() {
      // The hidden held slot follows invisibly, and a workspace showing a
      // single tile only shows tiles sliding to make room for a released one.
      if (isHeld || !slides) {
        position.value = displayIndex;
      } else {
        position.animateTo(displayIndex, curve: Curves.easeOutCubic);
      }
      return null;
    }, [displayIndex]);
    final shownAt = useAnimation(position);
    final insertsAfter =
        !isSettling &&
            mark != null &&
            mark.workspaceId == workspaceId &&
            mark.index == index
        ? mark.after
        : null;
    return FractionalTranslation(
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
                child: ColoredBox(color: Theme.of(context).colorScheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}

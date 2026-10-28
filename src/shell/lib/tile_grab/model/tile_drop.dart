import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'tile_drop.freezed.dart';

/// Where a held tile would land if it were released now.
@freezed
sealed class TileDropTarget with _$TileDropTarget {
  /// At [index] of [workspaceId]: the position the tile takes once dropped,
  /// counted without the tile itself. The slot right after the windows is the
  /// application launcher, so that index appends.
  const factory TileDropTarget.slot({
    required WorkspaceId workspaceId,
    required int index,
  }) = TileSlotTarget;

  /// At the end of [workspaceId] (a workspace button in the screen panel).
  const factory TileDropTarget.workspace({required WorkspaceId workspaceId}) =
      TileWorkspaceTarget;
}

/// What releasing a held tile does to the workspaces.
sealed class TileDropPlan {
  const TileDropPlan();
}

/// The tile stays where it is.
class TileDropNoop extends TileDropPlan {
  const TileDropNoop();
}

/// The tile moves within its own workspace, whose new order is [windowList].
class TileDropReorder extends TileDropPlan {
  const TileDropReorder(this.windowList);
  final IList<PersistentWindowId> windowList;
}

/// The tile moves to [workspaceId], inserted at [index].
class TileDropTransfer extends TileDropPlan {
  const TileDropTransfer({required this.workspaceId, required this.index});
  final WorkspaceId workspaceId;
  final int index;
}

/// The number of slots the tiles of [windowList] take besides
/// [heldWindowId]: the held tile leaves the flow of its own workspace.
int tileFlowLength(
  IList<PersistentWindowId> windowList,
  PersistentWindowId heldWindowId,
) => windowList.length - (windowList.contains(heldWindowId) ? 1 : 0);

/// The index [target] puts the held tile at in [windowList].
int _landingIndex(
  TileDropTarget target,
  IList<PersistentWindowId> windowList,
  PersistentWindowId heldWindowId,
) {
  final flowLength = tileFlowLength(windowList, heldWindowId);
  return switch (target) {
    TileSlotTarget(:final index) => index.clamp(0, flowLength),
    TileWorkspaceTarget() => flowLength,
  };
}

/// Resolves the drop of [windowId], held from [sourceWorkspaceId], on
/// [target], whose workspace currently lists [destinationWindowList].
///
/// The tile is inserted at the target index and the others shift; tiles are
/// never swapped.
TileDropPlan planTileDrop({
  required PersistentWindowId windowId,
  required WorkspaceId sourceWorkspaceId,
  required TileDropTarget target,
  required IList<PersistentWindowId> destinationWindowList,
}) {
  final index = _landingIndex(target, destinationWindowList, windowId);
  final from = destinationWindowList.indexOf(windowId);
  if (target.workspaceId != sourceWorkspaceId || from < 0) {
    return TileDropTransfer(workspaceId: target.workspaceId, index: index);
  }
  // Dropping a tile on its own workspace button leaves it in place.
  if (target is TileWorkspaceTarget || index == from) {
    return const TileDropNoop();
  }
  return TileDropReorder(
    destinationWindowList.removeAt(from).insert(index, windowId),
  );
}

/// The edge of a tile slot where a held tile would be inserted, in a
/// workspace showing a single tile: there the tiles do not move aside, since
/// a gap would empty the whole workspace, and a bar marks the edge instead.
typedef TileInsertionMark = ({WorkspaceId workspaceId, int index, bool after});

/// Whether a workspace showing [visibleLength] tiles opens a gap for a held
/// tile. With a single tile shown, the gap would empty the whole workspace,
/// so it only opens once the tile is released ([settling]): the shown tile
/// slides out as the released one lands in its place.
bool tileRowOpensGap(int visibleLength, {required bool settling}) =>
    visibleLength > 1 || settling;

/// The slot of [workspaceId] the gap for [heldWindowId] opens at, or `null`
/// when [target] does not land in that workspace.
int? tileGapIndex({
  required WorkspaceId workspaceId,
  required IList<PersistentWindowId> windowList,
  required PersistentWindowId? heldWindowId,
  required TileDropTarget? target,
}) => heldWindowId == null || target?.workspaceId != workspaceId
    ? null
    : _landingIndex(target!, windowList, heldWindowId);

/// The slot the committed slot [index] of [workspaceId] is shown at while
/// [heldWindowId] is held over [target].
///
/// In a workspace that [opensGap], the held tile leaves the flow of its own
/// workspace, and a gap opens where it would land, so the tiles show the
/// layout the drop would produce. With no target the drop would put the tile
/// back, so every tile stays put. The held tile's own (hidden) slot follows
/// the gap when it lands in its own workspace. [index] may be the launcher,
/// the slot after the windows. A workspace that does not open a gap keeps
/// every tile put.
int tileDisplayIndex({
  required WorkspaceId workspaceId,
  required IList<PersistentWindowId> windowList,
  required int index,
  required PersistentWindowId? heldWindowId,
  required TileDropTarget? target,
  required bool opensGap,
}) {
  if (!opensGap || heldWindowId == null || target == null) return index;
  final from = windowList.indexOf(heldWindowId);
  final gap = tileGapIndex(
    workspaceId: workspaceId,
    windowList: windowList,
    heldWindowId: heldWindowId,
    target: target,
  );
  if (index == from) return gap ?? index;
  final flowIndex = from >= 0 && index > from ? index - 1 : index;
  return gap != null && flowIndex >= gap ? flowIndex + 1 : flowIndex;
}

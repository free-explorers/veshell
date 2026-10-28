import 'package:flutter/painting.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/tile_grab/model/tile_drop.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'tile_grab.freezed.dart';

/// A tile held with `Super` + primary-button drag.
@freezed
abstract class TileGrab with _$TileGrab {
  const factory TileGrab({
    /// The pointer holding the tile.
    required int pointer,
    required PersistentWindowId windowId,
    required WorkspaceId sourceWorkspaceId,
    required ScreenId sourceScreenId,

    /// The tile's rect, in compositor-global logical coordinates, when it was
    /// grabbed. A cancelled grab flies the tile back there.
    required Rect originRect,

    /// Where the pointer grabbed the tile, as a fraction of its size, so
    /// the preview stays under the pointer at the same spot.
    required Offset grabAnchor,

    /// Where the pointer pressed the tile, in compositor-global logical
    /// coordinates. Until the tile lifts, it stays stuck around this point.
    required Offset pressPosition,

    /// The pointer position in compositor-global logical coordinates.
    required Offset globalPosition,

    /// Whether the pointer travelled far enough to lift the tile. A Super
    /// click that never moves is swallowed without moving anything.
    @Default(false) bool lifted,

    /// The screen under the pointer: Super+WASD navigates it while the tile is
    /// held.
    ScreenId? hoveredScreenId,
    TileDropTarget? target,

    /// The edge marked for the drop in a workspace showing a single tile.
    TileInsertionMark? insertionMark,

    /// Where the tile lands if released now, in compositor-global logical
    /// coordinates: the gap opened for it, or the workspace button.
    Rect? landingRect,

    /// Whether the tile was released and is flying to the rect it lands at,
    /// which is `landingRect` (or `originRect` when it goes back). The drop
    /// is committed once it gets there.
    @Default(false) bool settling,
  }) = _TileGrab;

  const TileGrab._();

  /// The tile's logical size when it was grabbed.
  Size get tileSize => originRect.size;
}

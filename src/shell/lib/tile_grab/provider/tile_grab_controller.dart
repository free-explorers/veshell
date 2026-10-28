import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Intent;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/shared/widget/multi_view_drag.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/tile_grab/model/tile_drop.dart';
import 'package:shell/tile_grab/model/tile_grab.dart';
import 'package:shell/tile_grab/model/tile_grab_marker.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'tile_grab_controller.g.dart';

/// Pointer travel, in logical pixels, before a Super-press lifts the tile.
///
/// Until then the tile stays stuck in its slot, only stretching towards the
/// pointer, and pops off once the pointer pulls this far.
const tileGrabLiftThreshold = 24.0;

/// How long a released tile takes to fly to where it lands.
const tileGrabSettleDuration = Duration(milliseconds: 240);

/// The tile held with `Super` + primary-button drag, or `null`.
///
/// The pointer is tracked through a global pointer route rather than a
/// `Draggable`: navigating while the tile is held can scroll the source
/// workspace off its screen and unmount the tile that started the grab. Every
/// tile slot watches this provider, so it lives as long as any workspace does.
///
/// A released tile first flies to where it lands (`TileGrab.settling`); the
/// drop is only committed once it gets there, so the tile reappears in its
/// slot on the frame the flying copy disappears.
@riverpod
class TileGrabController extends _$TileGrabController {
  ShellDragSource? _source;
  int? _pointer;
  Offset _downPosition = Offset.zero;
  Offset _sourcePosition = Offset.zero;
  Ticker? _ticker;
  Duration? _settleStart;
  TileDropPlan _settlePlan = const TileDropNoop();

  @override
  TileGrab? build() {
    ref.onDispose(_detach);
    return null;
  }

  /// Starts holding [windowId] with the pointer of [event], which went down
  /// in the [source] view on the tile at [tileRect] (in the view's
  /// coordinates).
  void start({
    required ShellDragSource source,
    required PointerDownEvent event,
    required PersistentWindowId windowId,
    required WorkspaceId workspaceId,
    required ScreenId screenId,
    required Rect tileRect,
  }) {
    if (state != null) return;
    _source = source;
    _pointer = event.pointer;
    _downPosition = event.position;
    _sourcePosition = event.position;
    _settleStart = null;
    GestureBinding.instance.pointerRouter.addRoute(
      event.pointer,
      _handlePointerEvent,
    );
    HardwareKeyboard.instance.addHandler(_handleKey);
    _ticker = Ticker(_onTick, debugLabel: 'TileGrab')..start();
    final local = event.position - tileRect.topLeft;
    state = TileGrab(
      pointer: event.pointer,
      windowId: windowId,
      sourceWorkspaceId: workspaceId,
      sourceScreenId: screenId,
      originRect: tileRect.shift(source.toGlobal(Offset.zero)),
      grabAnchor: tileRect.isEmpty
          ? Offset.zero
          : Offset(local.dx / tileRect.width, local.dy / tileRect.height),
      pressPosition: source.toGlobal(event.position),
      globalPosition: source.toGlobal(event.position),
      hoveredScreenId: screenId,
    );
  }

  /// Puts the held tile back where it came from.
  void cancel() {
    final grab = state;
    if (grab == null || grab.settling) return;
    if (!grab.lifted) {
      _clear();
      return;
    }
    // With no target, every tile goes back to its slot while the held one
    // flies home.
    _settle(grab.copyWith(target: null, landingRect: null));
  }

  /// Handles a shell intent on behalf of the held tile, returning whether it
  /// was consumed.
  ///
  /// Keyboard focus stays on the screen the grab started from, but the user
  /// navigates the screen under the pointer: navigation is redirected there
  /// so the layout slides beneath the held tile.
  bool handleIntent(Intent intent) {
    final grab = state;
    if (grab == null || grab.settling) return false;
    switch (intent) {
      case NavigateIntent(:final direction):
        _navigate(grab.hoveredScreenId ?? grab.sourceScreenId, direction);
        return true;
      // Moving the selected tile from the keyboard would fight the pointer,
      // and the overview would cover the drop targets.
      case MoveIntent():
      case ToggleOverviewIntent():
        return true;
      default:
        return false;
    }
  }

  void _navigate(ScreenId screenId, NavigationDirection direction) {
    final screen = ref.read(screenStateProvider(screenId).notifier);
    switch (direction) {
      case NavigationDirection.up:
        screen.selectAdjacentWorkspace(-1);
      case NavigationDirection.down:
        screen.selectAdjacentWorkspace(1);
      case NavigationDirection.left:
      case NavigationDirection.right:
        final screenState = ref.read(screenStateProvider(screenId));
        final workspaceId =
            screenState.workspaceList[screenState.selectedIndex];
        ref
            .read(workspaceStateProvider(workspaceId).notifier)
            .selectAdjacentTileable(
              direction == NavigationDirection.left ? -1 : 1,
            );
    }
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      cancel();
      return true;
    }
    return false;
  }

  void _handlePointerEvent(PointerEvent event) {
    switch (event) {
      case PointerMoveEvent():
        _sourcePosition = event.position;
        _refresh();
      case PointerUpEvent():
        _sourcePosition = event.position;
        _refresh();
        _drop();
      case PointerCancelEvent():
        cancel();
      default:
        break;
    }
  }

  void _onTick(Duration elapsed) {
    final grab = state;
    if (grab == null) return;
    if (!grab.settling) {
      _refresh();
      return;
    }
    final start = _settleStart ??= elapsed;
    if (elapsed - start >= tileGrabSettleDuration) unawaited(_commit(grab));
  }

  /// Re-resolves what is under the pointer. It runs on every frame too: a
  /// navigation key slides the layout under a pointer that does not move.
  void _refresh() {
    final grab = state;
    final source = _source;
    if (grab == null || grab.settling || source == null) return;
    if (!source.mounted) {
      cancel();
      return;
    }
    final global = source.toGlobal(_sourcePosition);
    final lifted =
        grab.lifted ||
        (_sourcePosition - _downPosition).distance > tileGrabLiftThreshold;
    final location = ShellDragView.locate(global);
    ScreenId? hoveredScreenId;
    TileDropTarget? target;
    TileInsertionMark? insertionMark;
    Rect? landingRect;
    for (final entry in location?.hitTest() ?? const <HitTestEntry>[]) {
      final renderObject = entry.target;
      if (renderObject is! RenderMetaData) continue;
      switch (renderObject.metaData) {
        case final TileRowMarker row
            when target == null && entry is BoxHitTestEntry:
          final extent = renderObject.size.width / row.visible;
          final scrollOffset = row.scrollOffset();
          final position = (entry.localPosition.dx + scrollOffset) / extent;
          final int slot;
          if (tileRowOpensGap(row.visible, settling: false)) {
            // The slot under the pointer, from the row's geometry: the gap
            // opens there and stays there while the pointer does.
            slot = position.floor().clamp(
              0,
              _flowLength(grab, row.workspaceId),
            );
            target = TileDropTarget.slot(
              workspaceId: row.workspaceId,
              index: slot,
            );
          } else {
            // A single tile is shown: nothing moves, and the half of the tile
            // under the pointer picks the edge it is inserted at.
            final windowList = ref
                .read(workspaceStateProvider(row.workspaceId))
                .tileableWindowList;
            slot = position.floor().clamp(0, windowList.length);
            final after =
                slot < windowList.length && position - position.floor() > 0.5;
            final insertion = slot + (after ? 1 : 0);
            final from = windowList.indexOf(grab.windowId);
            target = TileDropTarget.slot(
              workspaceId: row.workspaceId,
              index: from >= 0 && insertion > from ? insertion - 1 : insertion,
            );
            insertionMark = (
              workspaceId: row.workspaceId,
              index: slot,
              after: after,
            );
          }
          landingRect = _globalRect(
            location!,
            renderObject,
            Rect.fromLTWH(
              slot * extent - scrollOffset,
              0,
              extent,
              renderObject.size.height,
            ),
          );
        case TileWorkspaceButtonMarker(:final workspaceId) when target == null:
          target = TileDropTarget.workspace(workspaceId: workspaceId);
          landingRect = _globalRect(
            location!,
            renderObject,
            Offset.zero & renderObject.size,
          );
        case TileGrabScreenMarker(:final screenId):
          hoveredScreenId ??= screenId;
      }
    }
    // A drop that would change nothing (over the held tile's own slot or its
    // own workspace button) is no target: the tile would go back.
    if (!lifted || (target != null && _plan(grab, target) is TileDropNoop)) {
      target = null;
      insertionMark = null;
      landingRect = null;
    }
    final next = grab.copyWith(
      globalPosition: global,
      lifted: lifted,
      hoveredScreenId: hoveredScreenId ?? grab.hoveredScreenId,
      target: target,
      insertionMark: insertionMark,
      landingRect: landingRect,
    );
    if (next != grab) state = next;
  }

  int _flowLength(TileGrab grab, WorkspaceId workspaceId) => tileFlowLength(
    ref.read(workspaceStateProvider(workspaceId)).tileableWindowList,
    grab.windowId,
  );

  static Rect _globalRect(
    ShellDragLocation location,
    RenderBox box,
    Rect local,
  ) => Rect.fromPoints(
    location.toGlobal(box.localToGlobal(local.topLeft)),
    location.toGlobal(box.localToGlobal(local.bottomRight)),
  );

  TileDropPlan _plan(TileGrab grab, TileDropTarget target) => planTileDrop(
    windowId: grab.windowId,
    sourceWorkspaceId: grab.sourceWorkspaceId,
    target: target,
    destinationWindowList: ref
        .read(workspaceStateProvider(target.workspaceId))
        .tileableWindowList,
  );

  void _drop() {
    final grab = state;
    if (grab == null || grab.settling) return;
    if (!grab.lifted) {
      _clear();
      return;
    }
    _settle(grab);
  }

  /// Releases the pointer and keyboard, and flies [grab] to where it lands.
  /// The gap stays open meanwhile: the target is kept until the commit.
  void _settle(TileGrab grab) {
    final target = grab.target;
    _settlePlan = target == null ? const TileDropNoop() : _plan(grab, target);
    _releaseInput();
    _settleStart = null;
    state = grab.copyWith(settling: true);
  }

  Future<void> _commit(TileGrab grab) async {
    if (!identical(state, grab)) return;
    _ticker?.stop();
    final plan = _settlePlan;
    _settlePlan = const TileDropNoop();
    switch (plan) {
      case TileDropNoop():
        break;
      case TileDropReorder(:final windowList):
        ref.read(workspaceStateProvider(grab.target!.workspaceId).notifier)
          ..reorderWindowList(windowList)
          ..selectWindow(grab.windowId);
      case TileDropTransfer(:final workspaceId, :final index):
        // The destination's `insertWindow` owns the transfer, including the
        // removal from the source workspace. It is asynchronous: the tile
        // keeps flying at its landing rect until the destination lists it.
        await ref
            .read(workspaceStateProvider(workspaceId).notifier)
            .insertWindow(grab.windowId, index, selectWindow: true);
        if (!ref.mounted || !identical(state, grab)) return;
    }
    // Let one frame lay the tiles out in their new order while the grab still
    // settles (its slot hidden), then hand over from the flying copy.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (ref.mounted && identical(state, grab)) _clear();
      })
      ..scheduleFrame();
  }

  void _clear() {
    _detach();
    state = null;
  }

  void _releaseInput() {
    final pointer = _pointer;
    if (pointer != null) {
      GestureBinding.instance.pointerRouter.removeRoute(
        pointer,
        _handlePointerEvent,
      );
    }
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _pointer = null;
    _source = null;
  }

  void _detach() {
    _releaseInput();
    _ticker?.dispose();
    _ticker = null;
  }
}

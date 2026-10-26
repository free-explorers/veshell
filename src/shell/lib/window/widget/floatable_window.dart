import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_dragging_state.dart';
import 'package:shell/meta_window/provider/meta_window_resizing_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/meta_window/widget/meta_surface_decoration.dart';
import 'package:shell/meta_window/widget/meta_surface_resize_handle.dart';
import 'package:shell/platform/model/event/interactive_resize/interactive_resize.serializable.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/request/start_move_window/start_move_window.serializable.dart';
import 'package:shell/platform/model/request/start_resize_window/start_resize_window.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shared/util/snapping.dart';
import 'package:shell/shared/widget/container_with_positionnable_children/container_with_positionnable_children.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

/// How a [FloatableWindow] is presented.
///
/// [dialogOverlay] is the historical dialog-area presentation: the window is a
/// local Flutter overlay inside a tile, dragged locally. [floatingTile] is the
/// `DisplayMode.floating` escape hatch: the compositor owns the move, the
/// native X11 window is configured, and the shell renders from the observed
/// global position.
enum FloatableWindowPlacement { dialogOverlay, floatingTile }

/// Clamps a floating window origin so at least half of it stays inside the
/// available tile on each axis.
///
/// The window may extend outside by at most half of its own width/height. This
/// is uniform for small, viewport-sized and oversized windows.
Offset clampFloatingOrigin(Size available, Size window, Offset requested) {
  if (available.width <= 0 || available.height <= 0) {
    return requested;
  }
  final halfWidth = window.width / 2;
  final halfHeight = window.height / 2;
  final minDx = -halfWidth;
  final maxDx = available.width - halfWidth;
  final minDy = -halfHeight;
  final maxDy = available.height - halfHeight;

  return Offset(
    requested.dx.clamp(minDx, math.max(maxDx, minDx)).toDouble(),
    requested.dy.clamp(minDy, math.max(maxDy, minDy)).toDouble(),
  );
}

class FloatableWindow extends HookConsumerWidget {
  const FloatableWindow({
    required this.metaWindowId,
    this.placement = FloatableWindowPlacement.dialogOverlay,
    this.tileGlobalOrigin,
    this.maxSizeFactor = 1,
    this.clientOrigin,
    this.maximized = false,
    this.onRaise,
    super.key,
  });
  final MetaWindowId metaWindowId;

  /// Which presentation owns this window. Defaults to the dialog-area overlay
  /// so every existing `WindowDialogs` call site keeps its behaviour.
  final FloatableWindowPlacement placement;

  /// Top-left of the floating tile's content area in compositor-global logical
  /// coordinates. `null` outside a floating tile.
  final Offset? tileGlobalOrigin;

  /// The window's top-left in the tile's coordinate space, when the client
  /// placed it itself (an X11 application such as Zoom positioning its own
  /// panels). `null` centres the window, the default for a single window or a
  /// window that has not declared a position.
  final Offset? clientOrigin;

  /// Whether this floating window fills the whole stack.
  ///
  /// This is a resize, not the tile's `DisplayMode.maximized`: the window stays
  /// in the floating stack (other floating windows can still sit above it) but
  /// is configured to the stack's size.
  final bool maximized;

  /// Fraction of the available space the window may grow to. Used to keep a
  /// dialog from filling a maximized tile entirely and hiding the window
  /// behind it.
  final double maxSizeFactor;

  /// Called when the pointer goes down on the window, before the window
  /// processes the event. The floating stack uses it to raise the window (and
  /// activate it) above its siblings.
  final VoidCallback? onRaise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the auto-dispose drag provider alive for the lifetime of the
    // window; the move listener reads its current value on every pointer
    // event.
    ref.watch(metaWindowDraggingStateProvider(metaWindowId));
    final resizeInProgress = ref.watch(
      metaWindowResizingStateProvider(metaWindowId),
    );
    final metaWindow = ref.watch(metaWindowStateProvider(metaWindowId));
    // `texture` is null until the surface commits its first buffer; a null
    // check here would make a not-yet-committed dialog crash instead of
    // appearing as soon as it is ready.
    final surfaceSize = ref.watch(
      wlSurfaceStateProvider(
        metaWindow.surfaceId,
      ).select((v) => v.texture?.size),
    );

    final repositionnableControllerWidget = RepositionnableControllerWidget.of(
      context,
    );
    final constraints = repositionnableControllerWidget.constraints;

    final decorationHeight = metaWindow.needDecoration
        ? WindowTitleBar.height
        : 0.0;

    // `maxSizeFactor` below 1 caps the window to a fraction of the tile; the
    // main window and floating dialogs keep the default `1` and are untouched.
    final isCapped =
        maxSizeFactor < 1 &&
        constraints.biggest.width.isFinite &&
        constraints.biggest.height.isFinite;

    // Maximize is a resize of this floating window to the stack's bounds, not
    // the tile's `DisplayMode.maximized` (which would tab its dialogs again).
    final isMaximized =
        maximized &&
        constraints.hasBoundedWidth &&
        constraints.hasBoundedHeight;

    // The largest box the window may occupy, decoration included.
    final maxBoxSize = useMemoized(() => constraints.biggest * maxSizeFactor, [
      constraints,
      maxSizeFactor,
    ]);

    // The same cap expressed as the client's surface size: the box also holds
    // the decoration title bar. Used to configure resizable dialogs. Floored to
    // whole logical pixels so the configure matches the client's commit.
    final maxSurfaceSize = useMemoized(
      () => Size(
        maxBoxSize.width.floorToDouble(),
        (maxBoxSize.height - decorationHeight).floorToDouble(),
      ),
      [maxBoxSize, decorationHeight],
    );

    // The surface's own size (its buffer, CSD margins included), in logical
    // pixels: `geometry` is logical, the texture size is not.
    final logicalSurfaceSize = useMemoized(() {
      final size = surfaceSize;
      if (size == null) {
        return null;
      }
      final ratio = metaWindow.scaleRatio;
      return Size(size.width / ratio, size.height / ratio);
    }, [surfaceSize, metaWindow.scaleRatio]);

    // The size the window wants on its own, decoration included.
    final naturalBoxSize = useMemoized(
      () {
        // In floating mode the client geometry is the size the shell just
        // requested. Letting a lagging committed buffer win here makes the box
        // jump backwards on every resize frame until the next commit. Outside
        // floating mode keep the historical max(): a dialog can commit a buffer
        // taller than its reported geometry and must not be clipped.
        final width = metaWindow.displayMode == MetaWindowDisplayMode.floating
            ? (metaWindow.geometry?.width ?? logicalSurfaceSize?.width ?? 0)
            : math.max(
                metaWindow.geometry?.width ?? 0,
                logicalSurfaceSize?.width ?? 0,
              );
        final height =
            (metaWindow.displayMode == MetaWindowDisplayMode.floating
                ? (metaWindow.geometry?.height ??
                      logicalSurfaceSize?.height ??
                      0)
                : math.max(
                    metaWindow.geometry?.height ?? 0,
                    logicalSurfaceSize?.height ?? 0,
                  )) +
            decorationHeight;
        return Size(width, height);
      },
      [
        metaWindow.displayMode,
        metaWindow.geometry,
        logicalSurfaceSize,
        decorationHeight,
      ],
    );

    final metaSize = useMemoized(
      () => Size(
        math.min(naturalBoxSize.width, maxBoxSize.width),
        math.min(naturalBoxSize.height, maxBoxSize.height),
      ),
      [naturalBoxSize, maxBoxSize],
    );

    final size = useState(metaSize);

    useEffect(() {
      size.value = metaSize;
      return null;
    }, [metaSize]);

    Offset centredOrigin() => Offset(
      ((constraints.maxWidth - size.value.width) / 2).roundToDouble(),
      ((constraints.maxHeight - size.value.height) / 2).roundToDouble(),
    );

    Offset clampClientOrigin(Offset requested) =>
        clampFloatingOrigin(constraints.biggest, size.value, requested);

    // The compositor owns floating placement. Once it has placed the window,
    // render exactly where it says instead of re-clamping locally: a local
    // clamp during a compositor move/resize would feed a different origin back
    // into the client. Unplaced windows still use the local centre as their
    // first-frame fallback; the dialog overlay keeps its historical clamp.
    Offset applyClientOrigin(Offset requested) =>
        placement == FloatableWindowPlacement.floatingTile
        ? requested
        : clampClientOrigin(requested);

    // A floating tile sends a compositor-global rect, because the X11 adapter
    // must configure the native window there. Every other presentation sends
    // surface-local geometry. Keeping the two intents separate is the
    // message-boundary gate: `UpdateGeometry` never means a native position.
    void patchWindowRect(Rect rect) {
      final patch = placement == FloatableWindowPlacement.floatingTile
          ? MetaWindowPatchMessage.setWindowRect(
              id: metaWindowId,
              value: rect,
              isFloatingMode: true,
            )
          : MetaWindowPatchMessage.updateGeometry(
              id: metaWindowId,
              value: rect,
            );
      unawaited(
        ref.read(metaWindowStateProvider(metaWindowId).notifier).patch(patch),
      );
    }

    final origin = useState<Offset?>(
      clientOrigin == null ? centredOrigin() : clampClientOrigin(clientOrigin!),
    );

    // Remember the client geometry and global position before a maximize, so
    // leaving the maximized state can restore the window's own placement.
    final preMaximizeGeometry = useRef<Rect?>(null);
    final preMaximizePosition = useRef<Offset?>(null);
    final wasMaximized = useRef(false);
    useEffect(() {
      if (isMaximized && !wasMaximized.value) {
        wasMaximized.value = true;
        preMaximizeGeometry.value = metaWindow.geometry;
        preMaximizePosition.value = metaWindow.position;
      } else if (!isMaximized && wasMaximized.value) {
        wasMaximized.value = false;
        final previous = preMaximizeGeometry.value;
        final previousPosition = preMaximizePosition.value;
        preMaximizeGeometry.value = null;
        preMaximizePosition.value = null;
        if (previous != null) {
          final fallbackPosition =
              (tileGlobalOrigin ?? Offset.zero) +
              Offset(0, decorationHeight) +
              (origin.value ?? Offset.zero);
          final restorePosition = previousPosition ?? fallbackPosition;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) {
              return;
            }
            patchWindowRect(
              Rect.fromLTWH(
                restorePosition.dx,
                restorePosition.dy,
                previous.width,
                previous.height,
              ),
            );
          });
        }
      }
      return null;
    }, [isMaximized]);

    // Configure the client to the filling size. A fixed-size window cannot be
    // resized this way and is scaled by the render path instead.
    //
    // The target is derived from the tile constraints, not from the observed
    // client geometry. `lastMaximizedSize` is the *requested* target, so a
    // client that commits a slightly different size cannot restart the
    // configure loop (the old code re-patched on every 1 px commit).
    final maximizedTargetSize = useMemoized(
      () => Size(
        constraints.maxWidth.floorToDouble(),
        (constraints.maxHeight - decorationHeight).floorToDouble(),
      ),
      [constraints, decorationHeight],
    );
    final lastMaximizedSize = useRef<Size?>(null);
    final lastMaximizedOrigin = useRef<Offset?>(null);
    useEffect(
      () {
        if (!isMaximized) {
          lastMaximizedSize.value = null;
          lastMaximizedOrigin.value = null;
          return null;
        }
        if (metaWindow.isFixedSized) {
          return null;
        }
        final target = maximizedTargetSize;
        if (target.width <= 0 || target.height <= 0) {
          return null;
        }
        final globalPosition =
            (tileGlobalOrigin ?? Offset.zero) + Offset(0, decorationHeight);
        final originChanged = lastMaximizedOrigin.value != globalPosition;
        if (lastMaximizedSize.value == target && !originChanged) {
          return null;
        }
        lastMaximizedSize.value = target;
        lastMaximizedOrigin.value = globalPosition;

        final geometry = metaWindow.geometry;
        final sizeMatches =
            geometry != null &&
            (geometry.width - target.width).abs() < 1 &&
            (geometry.height - target.height).abs() < 1;
        // The size is already what we asked for and only the tile moved:
        // still re-configure the position so the native window follows.
        if (sizeMatches && !originChanged) {
          return null;
        }
        // `useEffect` runs during the first build, where modifying a
        // provider is forbidden; defer the patch to after the frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }
          patchWindowRect(
            Rect.fromLTWH(
              globalPosition.dx,
              globalPosition.dy,
              target.width,
              target.height,
            ),
          );
        });
        return null;
      },
      [
        isMaximized,
        maximizedTargetSize,
        tileGlobalOrigin,
        metaWindow.geometry,
        metaWindow.isFixedSized,
      ],
    );

    // A client that moves one of its own windows (X11 configure requests, which
    // Zoom uses for its panels) repositions it here too. The first value is
    // applied above; later ones follow. A user drag is compositor-owned and
    // never reaches this local path.
    final appliedClientOrigin = useRef<Offset?>(clientOrigin);
    useEffect(() {
      final requested = clientOrigin;
      if (requested == null || requested == appliedClientOrigin.value) {
        return null;
      }
      final next = applyClientOrigin(requested);
      appliedClientOrigin.value = requested;
      origin.value = next;
      return null;
    }, [clientOrigin]);

    // A resizable dialog bigger than the cap is configured down to it, so it
    // leaves the window behind visible. A smaller dialog is left alone, so a
    // manual shrink survives navigating away and back. At most one correction
    // per observed mismatch keeps a client that refuses the configure from
    // being re-patched in a loop.
    final lastCorrectedMismatch = useRef<String?>(null);
    useEffect(
      () {
        if (!isCapped || metaWindow.isFixedSized) {
          return null;
        }
        final geometry = metaWindow.geometry;
        if (geometry == null) {
          return null;
        }
        const tolerance = 1.0;
        if (geometry.width <= maxSurfaceSize.width + tolerance &&
            geometry.height <= maxSurfaceSize.height + tolerance) {
          return null;
        }
        final mismatch =
            '$metaWindowId|${maxSurfaceSize.width}x${maxSurfaceSize.height}'
            '|${geometry.size}';
        if (lastCorrectedMismatch.value == mismatch) {
          return null;
        }
        lastCorrectedMismatch.value = mismatch;
        final targetWidth = math.min(geometry.width, maxSurfaceSize.width);
        final targetHeight = math.min(geometry.height, maxSurfaceSize.height);
        // The box the corrected window occupies, decoration included.
        final correctedBoxSize = Size(
          targetWidth,
          targetHeight + decorationHeight,
        );
        final correctedOrigin = Offset(
          ((constraints.maxWidth - correctedBoxSize.width) / 2).roundToDouble(),
          ((constraints.maxHeight - correctedBoxSize.height) / 2)
              .roundToDouble(),
        );
        // The native configure loc is the client-surface position. For a
        // floating window that is the tile origin plus the box origin plus the
        // shell titlebar; for a dialog overlay the historical surface-local
        // value is kept.
        final globalPosition =
            placement == FloatableWindowPlacement.floatingTile
            ? (tileGlobalOrigin ?? Offset.zero) +
                  correctedOrigin +
                  Offset(0, decorationHeight)
            : Offset(geometry.left, geometry.top);
        // `useEffect` runs during the first build (in `initHook`), where
        // modifying a provider is forbidden; defer the patch to after the
        // frame, like the maximized tile sizing does.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }
          patchWindowRect(
            Rect.fromLTWH(
              globalPosition.dx,
              globalPosition.dy,
              targetWidth,
              targetHeight,
            ),
          );
          // The window shrank, keep it centred so it stays visible.
          origin.value = correctedOrigin;
        });
        return null;
      },
      [
        isCapped,
        metaWindow.isFixedSized,
        metaWindow.geometry,
        maxSurfaceSize,
        decorationHeight,
        constraints,
      ],
    );

    // Move effect
    useEffect(
      () {
        void onDragChange() {
          // A floating tile is moved by the compositor: the title bar starts a
          // native move request and the shell follows the observed position.
          // Applying local deltas here as well would double the movement.
          if (placement == FloatableWindowPlacement.floatingTile) {
            return;
          }
          final source = ref.read(
            metaWindowDraggingStateProvider(metaWindowId),
          );
          // A client-initiated move already moves the native window; the
          // resulting position patch is applied through `clientOrigin`. Only a
          // shell title-bar drag needs local pointer deltas, otherwise the two
          // movements add up.
          if (source != MetaWindowDragSource.shell) {
            return;
          }
          final delta =
              repositionnableControllerWidget.dragUpdateController.value.delta;
          origin.value = (origin.value ?? Offset.zero).translate(
            delta.dx,
            delta.dy,
          );
        }

        void onDragEnd() {
          final state = ref.read(metaWindowDraggingStateProvider(metaWindowId));
          if (state == null) {
            return;
          }
          ref
              .read(metaWindowDraggingStateProvider(metaWindowId).notifier)
              .stopDragging();
        }

        // Attach once, unconditionally: waiting for the drag state to flip
        // means the pointer move that starts the drag is missed, leaving the
        // window permanently offset from the cursor.
        repositionnableControllerWidget.dragUpdateController.addListener(
          onDragChange,
        );
        repositionnableControllerWidget.dragEndController.addListener(
          onDragEnd,
        );

        return () {
          repositionnableControllerWidget.dragUpdateController.removeListener(
            onDragChange,
          );
          repositionnableControllerWidget.dragEndController.removeListener(
            onDragEnd,
          );
        };
      },
      [
        repositionnableControllerWidget.dragUpdateController,
        repositionnableControllerWidget.dragEndController,
      ],
    );

    // Resize effect
    useEffect(
      () {
        // A floating tile never resizes locally: the resize handle only asks
        // Rust to start the gesture, and the authoritative size arrives as a
        // `SetWindowRect` model patch. The dialog overlay keeps the historical
        // local resize.
        if (placement == FloatableWindowPlacement.floatingTile) {
          return null;
        }
        final resizeInProgress = ref.read(
          metaWindowResizingStateProvider(metaWindowId),
        );
        if (resizeInProgress != null) {
          void onResizeChange() {
            var newSize = size.value;
            switch (resizeInProgress) {
              case ResizeEdge.none:
                // No resizing is in progress
                break;
              case ResizeEdge.top:
                newSize = Size(
                  size.value.width,
                  size.value.height -
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dy,
                );
                origin.value = Offset(
                  origin.value!.dx,
                  origin.value!.dy +
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dy,
                );
              case ResizeEdge.bottom:
                newSize = Size(
                  size.value.width,
                  size.value.height +
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dy,
                );
              case ResizeEdge.left:
                newSize = Size(
                  size.value.width -
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dx,
                  size.value.height,
                );
                origin.value = Offset(
                  origin.value!.dx +
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dx,
                  origin.value!.dy,
                );
              case ResizeEdge.topLeft:
                newSize = Size(
                  size.value.width -
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dx,
                  size.value.height -
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dy,
                );
                origin.value = Offset(
                  origin.value!.dx +
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dx,
                  origin.value!.dy +
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dy,
                );
              case ResizeEdge.bottomLeft:
                newSize = Size(
                  size.value.width -
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dx,
                  size.value.height +
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dy,
                );
                origin.value = Offset(
                  origin.value!.dx +
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dx,
                  origin.value!.dy,
                );
              case ResizeEdge.right:
                newSize = Size(
                  size.value.width +
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dx,
                  size.value.height,
                );
              case ResizeEdge.topRight:
                newSize = Size(
                  size.value.width +
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dx,
                  size.value.height -
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dy,
                );
                origin.value = Offset(
                  origin.value!.dx,
                  origin.value!.dy +
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dy,
                );
              case ResizeEdge.bottomRight:
                newSize = Size(
                  size.value.width +
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dx,
                  size.value.height +
                      repositionnableControllerWidget
                          .dragUpdateController
                          .value
                          .delta
                          .dy,
                );
            }
            size.value = Size(
              math.max(1, newSize.width),
              math.max(1, newSize.height),
            );
            final currentGeometry = ref.read(
              metaWindowStateProvider(
                metaWindowId,
              ).select((value) => value.geometry),
            );
            // The dialog overlay keeps its historical surface-local geometry;
            // floating tiles never run this local resize path.
            final resizePosition = Offset(
              currentGeometry!.left,
              currentGeometry.top,
            );
            patchWindowRect(
              Rect.fromLTWH(
                resizePosition.dx,
                resizePosition.dy,
                size.value.width,
                metaWindow.needDecoration
                    ? size.value.height - WindowTitleBar.height
                    : size.value.height,
              ),
            );
          }

          void onResizeEnd() {
            ref
                .read(metaWindowResizingStateProvider(metaWindowId).notifier)
                .stopResizing();
          }

          repositionnableControllerWidget.dragUpdateController.addListener(
            onResizeChange,
          );
          repositionnableControllerWidget.dragEndController.addListener(
            onResizeEnd,
          );
          return () {
            repositionnableControllerWidget.dragUpdateController.removeListener(
              onResizeChange,
            );
            repositionnableControllerWidget.dragEndController.removeListener(
              onResizeEnd,
            );
          };
        } else {
          return null;
        }
      },
      [
        repositionnableControllerWidget.dragUpdateController,
        repositionnableControllerWidget.dragEndController,
        resizeInProgress,
      ],
    );

    // A floating tile's server-drawn title bar starts a compositor-owned move.
    // The dialog-area overlay keeps the historical local drag instead, so this
    // callback is only provided for `floatingTile`.
    final onTitleBarMoveStart =
        placement == FloatableWindowPlacement.floatingTile
        ? () {
            // A maximized floating window is drawn at the tile origin; a move
            // would only move the native window and desynchronise the box.
            if (isMaximized) {
              return;
            }
            unawaited(
              ref
                  .read(platformManagerProvider.notifier)
                  .request(
                    StartMoveWindowRequest(
                      message: StartMoveWindowMessage(
                        metaWindowId: metaWindowId,
                      ),
                    ),
                  ),
            );
          }
        : null;

    final surface = MetaSurfaceWidget(
      metaWindowId: metaWindowId,
      decorated: metaWindow.needDecoration,
      onTitleBarMoveStart: onTitleBarMoveStart,
    );

    // The raise listener belongs to the surface, not to the whole handle box.
    // Wrapping the window from outside would sit above the deferred outside
    // handles and reject pointer positions outside its bounds before
    // `DeferredPointerHandler` can hit-test them.
    final surfaceWithRaise = onRaise == null
        ? surface
        : Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => onRaise!(),
            child: surface,
          );

    // A floating window has exactly one resize path: the handle asks Rust to
    // start the gesture, Rust owns the pointer and publishes the rect, and
    // Flutter only draws/hit-tests the affordance. Fixed-size and maximized
    // windows expose no resize handles.
    final compositorResize =
        placement == FloatableWindowPlacement.floatingTile &&
        !metaWindow.isFixedSized &&
        !isMaximized;
    final resizeEnabled =
        placement != FloatableWindowPlacement.floatingTile || compositorResize;
    final ValueChanged<ResizeEdge>? onResizeStart = compositorResize
        ? (edge) {
            geometryLog.info('resize-handle start id=$metaWindowId edge=$edge');
            onRaise?.call();
            unawaited(
              ref
                  .read(platformManagerProvider.notifier)
                  .request(
                    StartResizeWindowRequest(
                      message: StartResizeWindowMessage(
                        metaWindowId: metaWindowId,
                        edge: edge,
                      ),
                    ),
                  ),
            );
          }
        : null;

    final window = resizeEnabled
        ? WithResizeHandles(
            metaWindowId: metaWindowId,
            // Outside handles are reachable through the
            // `DeferredPointerHandler` inside `WithResizeHandles`, even though
            // the floating window itself is an exact-size `Positioned`.
            onResizeStart: onResizeStart,
            // A server-decorated surface draws its frame (and shadow) through
            // `MetaSurfaceDecoration`. A client-decorated surface already
            // carries both in its buffer and must be drawn as-is: wrapping it
            // here added a second backdrop shadow and clipped its own
            // decoration.
            child: surfaceWithRaise,
          )
        : surfaceWithRaise;

    // A fixed-size dialog cannot be resized through a configure. When it is
    // bigger than the cap it is scaled down uniformly (and centred) instead of
    // being squished or covering the window behind.
    final scaleDown = isCapped && metaWindow.isFixedSized;
    // A fixed-size client cannot be configured to the filling size, so scale
    // its unchanged buffer instead of stretching it.
    final fillFixed = isMaximized && metaWindow.isFixedSized;

    // Dragging and resizing accumulate raw pointer deltas, which are
    // fractional, so `origin` leaves the whole-pixel grid the window was
    // centred on. Snapping it only at paint time (and not in the accumulated
    // value) keeps the drag responsive while the client's buffer keeps mapping
    // 1:1, instead of being resampled bilinearly into a permanently soft
    // window.
    final renderOrigin = origin.value == null
        ? null
        : snapOffsetToWholePixels(origin.value!);

    final positionedSize = isMaximized
        ? Size(
            constraints.maxWidth.floorToDouble(),
            constraints.maxHeight.floorToDouble(),
          )
        : size.value;
    final positionedOrigin = isMaximized ? Offset.zero : renderOrigin;

    final content = scaleDown || fillFixed
        ? FittedBox(
            fit: fillFixed ? BoxFit.contain : BoxFit.scaleDown,
            child: SizedBox(
              width: naturalBoxSize.width,
              height: naturalBoxSize.height,
              child: window,
            ),
          )
        : window;

    return Positioned(
      left: positionedOrigin?.dx,
      top: positionedOrigin?.dy,
      width: positionedSize.width,
      height: positionedSize.height,
      // The listener lives inside the `Positioned` (which must stay a direct
      // child of the stack) and before the window, so a press raises the
      // window before any drag or resize handle acts on it.
      child: content,
    );
  }
}

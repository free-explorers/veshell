import 'dart:async';
import 'dart:math' as math;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_dragging_state.dart';
import 'package:shell/meta_window/provider/meta_window_resizing_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/meta_window/widget/meta_surface_decoration.dart';
import 'package:shell/meta_window/widget/meta_surface_resize_handle.dart';
import 'package:shell/platform/model/event/interactive_resize/interactive_resize.serializable.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/shared/widget/container_with_positionnable_children/container_with_positionnable_children.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

class FloatableWindow extends HookConsumerWidget {
  const FloatableWindow({
    required this.metaWindowId,
    this.maxSizeFactor = 1,
    super.key,
  });
  final MetaWindowId metaWindowId;

  /// Fraction of the available space the window may grow to. Used to keep a
  /// dialog from filling a maximized tile entirely and hiding the window
  /// behind it.
  final double maxSizeFactor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDragInProgress =
        ref.watch(metaWindowDraggingStateProvider(metaWindowId));
    final resizeInProgress =
        ref.watch(metaWindowResizingStateProvider(metaWindowId));
    final metaWindow = ref.watch(metaWindowStateProvider(metaWindowId));
    // `texture` is null until the surface commits its first buffer; a null
    // check here would make a not-yet-committed dialog crash instead of
    // appearing as soon as it is ready.
    final surfaceSize = ref.watch(
      wlSurfaceStateProvider(metaWindow.surfaceId).select(
        (v) => v.texture?.size,
      ),
    );

    final repositionnableControllerWidget =
        RepositionnableControllerWidget.of(context);
    final constraints = repositionnableControllerWidget.constraints;

    final decorationHeight =
        metaWindow.needDecoration ? WindowTitleBar.height : 0.0;

    // `maxSizeFactor` below 1 caps the window to a fraction of the tile; the
    // main window and floating dialogs keep the default `1` and are untouched.
    final isCapped =
        maxSizeFactor < 1 && constraints.biggest.width.isFinite &&
            constraints.biggest.height.isFinite;

    // The largest box the window may occupy, decoration included.
    final maxBoxSize = useMemoized(
      () => constraints.biggest * maxSizeFactor,
      [constraints, maxSizeFactor],
    );

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

    // The size the window wants on its own, decoration included.
    final naturalBoxSize = useMemoized(
      () {
        final width = metaWindow.geometry?.width ?? surfaceSize?.width ?? 0;
        final height =
            (metaWindow.geometry?.height ?? surfaceSize?.height ?? 0) +
                decorationHeight;
        return Size(width, height);
      },
      [metaWindow.geometry, surfaceSize, decorationHeight],
    );

    final metaSize = useMemoized(
      () => Size(
        min(naturalBoxSize.width, maxBoxSize.width),
        min(naturalBoxSize.height, maxBoxSize.height),
      ),
      [naturalBoxSize, maxBoxSize],
    );

    final size = useState(metaSize);

    useEffect(
      () {
        size.value = metaSize;
        return null;
      },
      [metaSize],
    );

    final origin = useState<Offset?>(
      Offset(
        ((constraints.maxWidth - size.value.width) / 2).roundToDouble(),
        ((constraints.maxHeight - size.value.height) / 2).roundToDouble(),
      ),
    );

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
        final targetWidth = min(geometry.width, maxSurfaceSize.width);
        final targetHeight = min(geometry.height, maxSurfaceSize.height);
        // The box the corrected window occupies, decoration included.
        final correctedBoxSize = Size(
          targetWidth,
          targetHeight + decorationHeight,
        );
        // `useEffect` runs during the first build (in `initHook`), where
        // modifying a provider is forbidden; defer the patch to after the
        // frame, like the maximized tile sizing does.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }
          unawaited(
            ref.read(metaWindowStateProvider(metaWindowId).notifier).patch(
                  UpdateGeometry(
                    id: metaWindowId,
                    value: Rect.fromLTWH(
                      geometry.left,
                      geometry.top,
                      targetWidth,
                      targetHeight,
                    ),
                  ),
                ),
          );
          // The window shrank, keep it centred so it stays visible.
          origin.value = Offset(
            ((constraints.maxWidth - correctedBoxSize.width) / 2)
                .roundToDouble(),
            ((constraints.maxHeight - correctedBoxSize.height) / 2)
                .roundToDouble(),
          );
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
        final dragInProgress =
            ref.read(metaWindowDraggingStateProvider(metaWindowId));
        if (dragInProgress) {
          void onDragChange() {
            origin.value = (origin.value ?? Offset.zero).translate(
              repositionnableControllerWidget
                  .dragUpdateController.value.delta.dx,
              repositionnableControllerWidget
                  .dragUpdateController.value.delta.dy,
            );
          }

          void onDragEnd() {
            ref
                .read(metaWindowDraggingStateProvider(metaWindowId).notifier)
                .stopDragging();
          }

          repositionnableControllerWidget.dragUpdateController
              .addListener(onDragChange);

          repositionnableControllerWidget.dragEndController
              .addListener(onDragEnd);

          return () {
            repositionnableControllerWidget.dragUpdateController
                .removeListener(onDragChange);
            repositionnableControllerWidget.dragEndController
                .removeListener(onDragEnd);
          };
        } else {
          return null;
        }
      },
      [
        repositionnableControllerWidget.dragUpdateController,
        repositionnableControllerWidget.dragEndController,
        isDragInProgress,
      ],
    );

    // Resize effect
    useEffect(
      () {
        final resizeInProgress =
            ref.read(metaWindowResizingStateProvider(metaWindowId));
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
                          .dragUpdateController.value.delta.dy,
                );
                origin.value = Offset(
                  origin.value!.dx,
                  origin.value!.dy +
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dy,
                );
              case ResizeEdge.bottom:
                newSize = Size(
                  size.value.width,
                  size.value.height +
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dy,
                );
              case ResizeEdge.left:
                newSize = Size(
                  size.value.width -
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dx,
                  size.value.height,
                );
                origin.value = Offset(
                  origin.value!.dx +
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dx,
                  origin.value!.dy,
                );
              case ResizeEdge.topLeft:
                newSize = Size(
                  size.value.width -
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dx,
                  size.value.height -
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dy,
                );
                origin.value = Offset(
                  origin.value!.dx +
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dx,
                  origin.value!.dy +
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dy,
                );
              case ResizeEdge.bottomLeft:
                newSize = Size(
                  size.value.width -
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dx,
                  size.value.height +
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dy,
                );
                origin.value = Offset(
                  origin.value!.dx +
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dx,
                  origin.value!.dy,
                );
              case ResizeEdge.right:
                newSize = Size(
                  size.value.width +
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dx,
                  size.value.height,
                );
              case ResizeEdge.topRight:
                newSize = Size(
                  size.value.width +
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dx,
                  size.value.height -
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dy,
                );
                origin.value = Offset(
                  origin.value!.dx,
                  origin.value!.dy +
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dy,
                );
              case ResizeEdge.bottomRight:
                newSize = Size(
                  size.value.width +
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dx,
                  size.value.height +
                      repositionnableControllerWidget
                          .dragUpdateController.value.delta.dy,
                );
            }
            size.value = Size(
              math.max(1, newSize.width),
              math.max(1, newSize.height),
            );
            final currentGeometry = ref.read(
              metaWindowStateProvider(metaWindowId).select(
                (value) => value.geometry,
              ),
            );
            ref.read(metaWindowStateProvider(metaWindowId).notifier).patch(
                  UpdateGeometry(
                    id: metaWindowId,
                    value: Rect.fromLTWH(
                      currentGeometry!.left,
                      currentGeometry.top,
                      size.value.width,
                      metaWindow.needDecoration
                          ? size.value.height - WindowTitleBar.height
                          : size.value.height,
                    ),
                  ),
                );
          }

          void onResizeEnd() {
            ref
                .read(metaWindowResizingStateProvider(metaWindowId).notifier)
                .stopResizing();
          }

          repositionnableControllerWidget.dragUpdateController
              .addListener(onResizeChange);
          repositionnableControllerWidget.dragEndController
              .addListener(onResizeEnd);
          return () {
            repositionnableControllerWidget.dragUpdateController
                .removeListener(onResizeChange);
            repositionnableControllerWidget.dragEndController
                .removeListener(onResizeEnd);
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

    final window = WithResizeHandles(
      metaWindowId: metaWindowId,
      child: MetaSurfaceWidget(
        metaWindowId: metaWindowId,
        decorated: metaWindow.needDecoration,
      ),
    );

    // A fixed-size dialog cannot be resized through a configure. When it is
    // bigger than the cap it is scaled down uniformly (and centred) instead of
    // being squished or covering the window behind.
    final scaleDown = isCapped && metaWindow.isFixedSized;

    return Positioned(
      left: origin.value?.dx,
      top: origin.value?.dy,
      width: size.value.width,
      height: size.value.height,
      child: scaleDown
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: naturalBoxSize.width,
                height: naturalBoxSize.height,
                child: window,
              ),
            )
          : window,
    );
  }
}

import 'dart:math' as math;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/provider/meta_window_dragging_state.dart';
import 'package:shell/meta_window/provider/meta_window_resizing_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/meta_window/widget/meta_surface_resize_handle.dart';
import 'package:shell/shared/widget/container_with_positionnable_children/container_with_positionnable_children.dart';
import 'package:shell/wayland/model/event/interactive_resize/interactive_resize.serializable.dart';
import 'package:shell/wayland/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/window/model/window_base.dart';

class FloatableWindow extends HookConsumerWidget {
  const FloatableWindow({required this.window, super.key});
  final Window window;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDragInProgress =
        ref.watch(metaWindowDraggingStateProvider(window.metaWindowId!));
    final resizeInProgress =
        ref.watch(metaWindowResizingStateProvider(window.metaWindowId!));
    final metaWindow = ref.watch(metaWindowStateProvider(window.metaWindowId!));
    final surfaceSize = ref.watch(
      wlSurfaceStateProvider(metaWindow.surfaceId).select(
        (v) => v.texture!.size,
      ),
    );

    final repositionnableControllerWidget =
        RepositionnableControllerWidget.of(context);

    final metaSize = useMemoized(
      () {
        final width = metaWindow.geometry?.width ?? surfaceSize.width;
        var height = metaWindow.geometry?.height ?? surfaceSize.height;
        if (metaWindow.needDecoration) {
          height += 40;
        }
        final maxSize = repositionnableControllerWidget.constraints.biggest;

        return Size(
          min(width, maxSize.width),
          min(height, maxSize.height),
        );
      },
      [metaWindow.geometry, surfaceSize],
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
        ((repositionnableControllerWidget.constraints.maxWidth -
                    size.value.width) /
                2)
            .roundToDouble(),
        ((repositionnableControllerWidget.constraints.maxHeight -
                    size.value.height) /
                2)
            .roundToDouble(),
      ),
    );

    // Move effect
    useEffect(
      () {
        final dragInProgress =
            ref.read(metaWindowDraggingStateProvider(metaWindow.id));
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
                .read(metaWindowDraggingStateProvider(metaWindow.id).notifier)
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
            ref.read(metaWindowResizingStateProvider(metaWindow.id));
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
              metaWindowStateProvider(metaWindow.id).select(
                (value) => value.geometry,
              ),
            );
            ref.read(metaWindowStateProvider(metaWindow.id).notifier).patch(
                  UpdateGeometry(
                    id: metaWindow.id,
                    value: Rect.fromLTWH(
                      currentGeometry!.left,
                      currentGeometry.top,
                      size.value.width,
                      metaWindow.needDecoration
                          ? size.value.height - 40
                          : size.value.height,
                    ),
                  ),
                );
          }

          void onResizeEnd() {
            ref
                .read(metaWindowResizingStateProvider(metaWindow.id).notifier)
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

    return Positioned(
      left: origin.value?.dx,
      top: origin.value?.dy,
      width: size.value.width,
      height: size.value.height,
      child: WithResizeHandles(
        metaWindowId: metaWindow.id,
        child: MetaSurfaceWidget(
          metaWindowId: metaWindow.id,
          decorated: metaWindow.needDecoration,
        ),
      ),
    );
  }
}

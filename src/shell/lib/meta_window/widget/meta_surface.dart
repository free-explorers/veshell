import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_popup_for_id.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_popup.dart';
import 'package:shell/meta_window/widget/meta_surface_decoration.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/widget/surface.dart';
import 'package:shell/wayland/widget/surface/pointer_listener.dart';
import 'package:shell/wayland/widget/surface/surface_focus.dart';

class MetaSurfaceWidget extends HookConsumerWidget {
  const MetaSurfaceWidget({
    required this.metaWindowId,
    required this.decorated,
    this.focusNode,
    super.key,
  });
  final MetaWindowId metaWindowId;
  final FocusNode? focusNode;
  final bool decorated;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaWindow = ref.watch(
      metaWindowStateProvider(metaWindowId),
    );

    final surfaceId = ref.watch(
      metaWindowStateProvider(metaWindowId).select((value) => value.surfaceId),
    );
    final popups = ref.watch(metaPopupForIdProvider(metaWindowId));
    final offset = Offset(
      -1 * (metaWindow.geometry?.left ?? 0),
      -1 * (metaWindow.geometry?.top ?? 0),
    );

    final currentMonitor = CurrentMonitorName.of(context);
    geometryLog.fine(
      'window layout id=$metaWindowId surface=$surfaceId '
      'geometry=${metaWindow.geometry} offset=$offset '
      'scale=${metaWindow.scaleRatio} monitor=$currentMonitor',
    );

    // Measure the sizing contract: the shell patches `geometry` to the tile
    // bounds in maximized/fullscreen mode and the client is expected to commit
    // a buffer of the same logical size. A client that ignores the configure
    // (e.g. a fixed-size window) leaves the committed texture at its own size,
    // which shows up here as `match=false`. Logged only when the measured
    // tuple changes so a repainting client does not flood the log.
    final committedSurfaceSize = ref.watch(
      wlSurfaceStateProvider(surfaceId).select((v) => v.texture?.size),
    );
    final targetSize = metaWindow.geometry?.size;
    final logicalSize = committedSurfaceSize == null
        ? null
        : Size(
            committedSurfaceSize.width / metaWindow.scaleRatio,
            committedSurfaceSize.height / metaWindow.scaleRatio,
          );
    final lastSizingSignature = useRef<String?>(null);
    final sizingSignature = '$targetSize|$logicalSize|'
        '${metaWindow.isFixedSized}|${metaWindow.scaleRatio}';
    useEffect(
      () {
        if (lastSizingSignature.value == sizingSignature) {
          return null;
        }
        lastSizingSignature.value = sizingSignature;
        final matches = targetSize != null &&
            logicalSize != null &&
            (targetSize.width - logicalSize.width).abs() < 1 &&
            (targetSize.height - logicalSize.height).abs() < 1;
        geometryLog.info(
          'sizing surface id=$metaWindowId surface=$surfaceId '
          'target=$targetSize actual=$logicalSize '
          'fixed=${metaWindow.isFixedSized} '
          'scale=${metaWindow.scaleRatio} match=$matches',
        );
        return null;
      },
      [sizingSignature],
    );
    useEffect(
      () {
        if (ref.read(metaWindowStateProvider(metaWindowId)).currentOutput !=
            currentMonitor) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(metaWindowStateProvider(metaWindowId).notifier)
                .patch(
                  MetaWindowPatchMessage.updateCurrentOutput(
                    id: metaWindowId,
                    value: currentMonitor,
                  ),
                );
          });
        }
        return null;
      },
      [currentMonitor],
    );
    return Center(
      child: SurfaceFocus(
        focusNode: focusNode,
        child: ActivateSurfaceOnPointerDown(
          surfaceId: surfaceId,
          // Be sure to not put pointer listener behind the DeferredPointerHandler
          // Since Hit detection between DeferPointer and the handler are bypassed
          child: DeferredPointerHandler(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: AlignmentDirectional.center,
              children: [
                Positioned(
                  left: offset.dx,
                  top: offset.dy,
                  child: MetaSurfaceDecoration(
                    metaWindowId: metaWindowId,
                    enabled: decorated,
                    child: SurfaceWidget(
                      surfaceId: surfaceId,
                      scaleRatio: metaWindow.scaleRatio,
                    ),
                  ),
                ),
                for (final popupId in popups)
                  MetaPopupWidget(metaPopupId: popupId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    final geometry = ref.watch(
      metaWindowStateProvider(metaWindowId).select((value) => value.geometry),
    );

    final surfaceId = ref.watch(
      metaWindowStateProvider(metaWindowId).select((value) => value.surfaceId),
    );
    final popups = ref.watch(metaPopupForIdProvider(metaWindowId));
    final offset = Offset(
      -1 * (geometry?.left ?? 0),
      -1 * (geometry?.top ?? 0),
    );

    final currentMonitor = CurrentMonitorName.of(context);
    useEffect(
      () {
        if (ref.read(metaWindowStateProvider(metaWindowId)).currentOutput !=
            currentMonitor) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(metaWindowStateProvider(metaWindowId).notifier).patch(
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

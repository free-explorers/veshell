import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_popup_for_id.dart';
import 'package:shell/meta_window/provider/meta_window_resizing_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_popup.dart';
import 'package:shell/meta_window/widget/meta_surface_decoration.dart';
import 'package:shell/wayland/model/event/meta_window_patches/meta_window_patches.serializable.dart';
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
    final resizeInProgress =
        ref.watch(metaWindowResizingStateProvider(metaWindowId));
    return DeferredPointerHandler(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return HookBuilder(
            builder: (context) {
              useEffect(
                () {
                  if (constraints.widthConstraints().maxWidth.isInfinite ||
                      constraints.heightConstraints().maxHeight.isInfinite ||
                      resizeInProgress != null) {
                    return null;
                  }
                  /* ref.read(waylandManagerProvider.notifier).request(
                        ResizeWindowRequest(
                          message: ResizeWindowMessage(
                            metaWindowId: metaWindowId,
                            width: constraints.maxWidth.round(),
                            height: decorated
                                ? constraints.maxHeight.round() - 40
                                : constraints.maxHeight.round(),
                          ),
                        ),
                      ); */
                  WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                    ref
                        .read(metaWindowStateProvider(metaWindowId).notifier)
                        .patch(
                          UpdateGeometry(
                            id: metaWindowId,
                            value: Rect.fromLTWH(
                              geometry!.left,
                              geometry.top,
                              constraints.maxWidth,
                              decorated
                                  ? constraints.maxHeight - 40
                                  : constraints.maxHeight,
                            ),
                          ),
                        );
                  });
                  return null;
                },
                [constraints],
              );

              final offset = Offset(
                -1 * (geometry?.left ?? 0),
                -1 * (geometry?.top ?? 0),
              );

              return Center(
                child: SurfaceFocus(
                  focusNode: focusNode,
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
                          child: ActivateSurfaceOnPointerDown(
                            surfaceId: surfaceId,
                            child: SurfaceWidget(
                              surfaceId: surfaceId,
                            ),
                          ),
                        ),
                      ),
                      for (final popupId in popups)
                        MetaPopupWidget(metaPopupId: popupId),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

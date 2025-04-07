import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/xdg_surface_state.dart';
import 'package:shell/wayland/widget/surface.dart';
import 'package:shell/wayland/widget/surface/pointer_listener.dart';
import 'package:shell/wayland/widget/surface/surface_focus.dart';
import 'package:shell/wayland/widget/surface/xdg_popup/popup.dart';

class XdgToplevelSurfaceWidget extends ConsumerWidget {
  const XdgToplevelSurfaceWidget({
    required this.surfaceId,
    this.focusNode,
    super.key,
  });
  final FocusNode? focusNode;

  final SurfaceId surfaceId;

  void _collectPopupList(
    List<SurfaceId> ids,
    WidgetRef ref,
    SurfaceId surfaceId,
  ) {
    final popups = ref
        .watch(
          xdgSurfaceStateProvider(surfaceId).select((value) => value.popups),
        )
        .where(
          (popup) => ref.watch(
            xdgSurfaceStateProvider(popup).select((value) => value.mapped),
          ),
        );
    ids.addAll(popups);
    for (final popupId in popups) {
      _collectPopupList(ids, ref, popupId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popupList = <SurfaceId>[];
    _collectPopupList(popupList, ref, surfaceId);
    final xdgState = ref.watch(xdgSurfaceStateProvider(surfaceId));
    final offset = Offset(
      -1 * (xdgState.geometry?.left ?? 0),
      -1 * (xdgState.geometry?.top ?? 0),
    );
    return SurfaceFocus(
      focusNode: focusNode,
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: offset & (xdgState.geometry?.size ?? Size.zero),
            child: ActivateSurfaceOnPointerDown(
              surfaceId: surfaceId,
              child: SurfaceWidget(
                surfaceId: surfaceId,
              ),
            ),
          ),
          for (final popupSurfaceId in popupList)
            PopupWidget(surfaceId: popupSurfaceId),
        ],
      ),
    );
  }
}

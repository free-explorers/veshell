import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_popup.serializable.dart';
import 'package:shell/meta_window/provider/meta_popup_state.dart';
import 'package:shell/wayland/widget/surface.dart';

class MetaPopupWidget extends HookConsumerWidget {
  const MetaPopupWidget({
    required this.metaPopupId,
    super.key,
  });

  final MetaPopupId metaPopupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaPopup = ref.watch(metaPopupStateProvider(metaPopupId));
    return Positioned(
      left: metaPopup.position.dx,
      top: metaPopup.position.dy,
      child: SurfaceWidget(
        surfaceId: metaPopup.surfaceId,
      ),
    );
  }
}

/* class _Positioner extends HookConsumerWidget {
  const _Positioner({
    required this.surfaceId,
    required this.child,
  });

  final SurfaceId surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const offset = Offset.zero;

    // Sum recursively positions until we reach the toplevel.
    while (ref.read(wlSurfaceStateProvider(id)).role == SurfaceRole.xdgPopup) {
      final popup = xdgPopupStateProvider(id);
      offset += ref.watch(popup.select((popup) => popup.position));
      // Change the origin of the popup to its visible bounds top left corner.
      offset -= _getVisibleBoundsTopLeft(ref, id);
      id = ref.watch(popup.select((popup) => popup.parent));
      // Position the popup relative to its parent's visible bounds top left
      // corner.
      offset += _getVisibleBoundsTopLeft(ref, id);
    }

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: child,
    );
  } */

/*   Offset _getVisibleBoundsTopLeft(WidgetRef ref, SurfaceId id) {
    final geometry = ref.watch(
      xdgSurfaceStateProvider(id).select((xdgSurface) => xdgSurface.geometry),
    );
    return geometry?.topLeft ?? Offset.zero;
  } 
 }
  */

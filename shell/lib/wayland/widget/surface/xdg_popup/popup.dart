import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/provider/xdg_popup_state.dart';
import 'package:shell/wayland/provider/xdg_surface_state.dart';
import 'package:shell/wayland/widget/surface.dart';

class PopupWidget extends StatelessWidget {
  const PopupWidget({
    required this.surfaceId,
    super.key,
  });

  final SurfaceId surfaceId;

  @override
  Widget build(BuildContext context) {
    return _Positioner(
      surfaceId: surfaceId,
      child: SurfaceWidget(
        surfaceId: surfaceId,
      ),
    );
  }
}

class _Positioner extends HookConsumerWidget {
  const _Positioner({
    required this.surfaceId,
    required this.child,
  });

  final SurfaceId surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var offset = Offset.zero;
    var id = surfaceId;

    // Sum recursively positions until we reach the toplevel.
    while (ref.read(wlSurfaceStateProvider(id)).role == SurfaceRole.xdgPopup) {
      final popup = xdgPopupStateProvider(id);
      offset += ref.watch(popup.select((popup) => popup.position));
      // Coordinates are always relative to the visible bounds.
      offset -= _getVisibleBoundsTopLeft(ref, id);
      id = ref.watch(popup.select((popup) => popup.parent));
      offset += _getVisibleBoundsTopLeft(ref, id);
    }

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: child,
    );
  }

  Offset _getVisibleBoundsTopLeft(WidgetRef ref, SurfaceId id) {
    final geometry = ref.watch(
      xdgSurfaceStateProvider(id).select((xdgSurface) => xdgSurface.geometry),
    );
    return geometry?.topLeft ?? Offset.zero;
  }
}

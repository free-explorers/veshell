import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/provider/xdg_popup_state.dart';
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
      final provider = xdgPopupStateProvider(id);
      offset += ref.watch(provider.select((popup) => popup.position));
      id = ref.watch(provider.select((popup) => popup.parent));
    }

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: child,
    );
  }
}

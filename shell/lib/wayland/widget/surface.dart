import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/subsurface_state.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/widget/subsurface.dart';
import 'package:shell/wayland/widget/surface/view_input_listener.dart';
import 'package:shell/wayland/widget/surface_size.dart';

class SurfaceWidget extends ConsumerWidget {
  const SurfaceWidget({
    required this.surfaceId,
    super.key,
  });
  final SurfaceId surfaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SurfaceSize(
      surfaceId: surfaceId,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _Subsurfaces(
            surfaceId: surfaceId,
            layer: _SubsurfaceLayer.below,
          ),
          ViewInputListener(
            surfaceId: surfaceId,
            child: Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                final textureId = ref.watch(
                  wlSurfaceStateProvider(surfaceId)
                      .select((v) => v.texture!.id),
                );

                return Texture(
                  textureId: textureId,
                );
              },
            ),
          ),
          _Subsurfaces(
            surfaceId: surfaceId,
            layer: _SubsurfaceLayer.above,
          ),
        ],
      ),
    );
  }
}

class _Subsurfaces extends ConsumerWidget {
  const _Subsurfaces({
    required this.surfaceId,
    required this.layer,
  });
  final SurfaceId surfaceId;
  final _SubsurfaceLayer layer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selector = layer == _SubsurfaceLayer.below
        ? (WlSurface ss) => ss.subsurfacesBelow
        : (WlSurface ss) => ss.subsurfacesAbove;

    final List<Widget> subsurfaces = ref
        .watch(wlSurfaceStateProvider(surfaceId).select(selector))
        .where(
          (id) =>
              ref.watch(subsurfaceStateProvider(id).select((ss) => ss.mapped)),
        )
        .map((id) => SubsurfaceWidget(surfaceId: id))
        .toList();

    return Stack(
      clipBehavior: Clip.none,
      children: subsurfaces,
    );
  }
}

enum _SubsurfaceLayer { below, above }

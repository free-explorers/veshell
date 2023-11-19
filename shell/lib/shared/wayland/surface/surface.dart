import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:veshell/shared/wayland/subsurface/subsurface.dart';
import 'package:veshell/shared/wayland/subsurface/subsurface.provider.dart';
import 'package:veshell/shared/wayland/surface/surface.model.dart';
import 'package:veshell/shared/wayland/surface/surface.provider.dart';
import 'package:veshell/shared/wayland/surface/surface_size.dart';
import 'package:veshell/shared/wayland/view_input_listener.dart';

class SurfaceWidget extends ConsumerWidget {
  const SurfaceWidget({
    required this.viewId,
    super.key,
  });
  final int viewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SurfaceSize(
      viewId: viewId,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _Subsurfaces(
            viewId: viewId,
            layer: _SubsurfaceLayer.below,
          ),
          ViewInputListener(
            viewId: viewId,
            child: Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                final key = ref.watch(
                  surfaceStatesProvider(viewId).select((v) => v.textureKey),
                );
                final textureId = ref.watch(
                  surfaceStatesProvider(viewId)
                      .select((v) => v.textureId.value),
                );

                return Texture(
                  key: key,
                  textureId: textureId,
                );
              },
            ),
          ),
          _Subsurfaces(
            viewId: viewId,
            layer: _SubsurfaceLayer.above,
          ),
        ],
      ),
    );
  }
}

class _Subsurfaces extends ConsumerWidget {
  const _Subsurfaces({
    required this.viewId,
    required this.layer,
  });
  final int viewId;
  final _SubsurfaceLayer layer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selector = layer == _SubsurfaceLayer.below
        ? (SurfaceState ss) => ss.subsurfacesBelow
        : (SurfaceState ss) => ss.subsurfacesAbove;

    List<Widget> subsurfaces = ref
        .watch(surfaceStatesProvider(viewId).select(selector))
        .where(
          (id) =>
              ref.watch(subsurfaceStatesProvider(id).select((ss) => ss.mapped)),
        )
        .map((id) => SubsurfaceWidget(viewId: id))
        .toList();

    return Stack(
      clipBehavior: Clip.none,
      children: subsurfaces,
    );
  }
}

enum _SubsurfaceLayer { below, above }

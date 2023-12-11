import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/manager/surface/subsurface/subsurface.dart';
import 'package:shell/manager/surface/subsurface/subsurface.provider.dart';
import 'package:shell/manager/surface/surface/surface.model.dart';
import 'package:shell/manager/surface/surface/surface.provider.dart';
import 'package:shell/manager/surface/surface/surface_size.dart';
import 'package:shell/manager/surface/view_input_listener.dart';

class SurfaceWidget extends ConsumerWidget {
  const SurfaceWidget({
    required this.surfaceId,
    super.key,
  });
  final int surfaceId;

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
                final key = ref.watch(
                  surfaceStatesProvider(surfaceId).select((v) => v.textureKey),
                );
                final textureId = ref.watch(
                  surfaceStatesProvider(surfaceId)
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
  final int surfaceId;
  final _SubsurfaceLayer layer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selector = layer == _SubsurfaceLayer.below
        ? (SurfaceState ss) => ss.subsurfacesBelow
        : (SurfaceState ss) => ss.subsurfacesAbove;

    final List<Widget> subsurfaces = ref
        .watch(surfaceStatesProvider(surfaceId).select(selector))
        .where(
          (id) =>
              ref.watch(subsurfaceStatesProvider(id).select((ss) => ss.mapped)),
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

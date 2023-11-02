import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/common/state/subsurface_state.dart';
import 'package:zenith/ui/common/state/surface_state.dart';
import 'package:zenith/ui/common/subsurface.dart';
import 'package:zenith/ui/common/surface_size.dart';
import 'package:zenith/ui/common/view_input_listener.dart';

class Surface extends ConsumerWidget {
  final int viewId;

  const Surface({
    super.key,
    required this.viewId,
  });

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
                Key key = ref.watch(surfaceStatesProvider(viewId).select((v) => v.textureKey));
                int textureId = ref.watch(surfaceStatesProvider(viewId).select((v) => v.textureId.value));

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
  final int viewId;
  final _SubsurfaceLayer layer;

  const _Subsurfaces({
    required this.viewId,
    required this.layer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selector = layer == _SubsurfaceLayer.below
        ? (SurfaceState ss) => ss.subsurfacesBelow
        : (SurfaceState ss) => ss.subsurfacesAbove;

    List<Widget> subsurfaces = ref
        .watch(surfaceStatesProvider(viewId).select(selector))
        .where((id) => ref.watch(subsurfaceStatesProvider(id).select((ss) => ss.mapped)))
        .map((id) => Subsurface(viewId: id))
        .toList();

    return Stack(
      clipBehavior: Clip.none,
      children: subsurfaces,
    );
  }
}

enum _SubsurfaceLayer { below, above }

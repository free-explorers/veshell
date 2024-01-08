import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/manager/wayland/surface/subsurface/subsurface.provider.dart';
import 'package:shell/manager/wayland/surface/wl_surface/surface.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';

class SubsurfaceWidget extends StatelessWidget {
  const SubsurfaceWidget({
    required this.surfaceId,
    super.key,
  });
  final SurfaceId surfaceId;

  @override
  Widget build(BuildContext context) {
    return _Positioner(
      surfaceId: surfaceId,
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          return SurfaceWidget(
            surfaceId: surfaceId,
          );
        },
      ),
    );
  }
}

class _Positioner extends ConsumerWidget {
  const _Positioner({
    required this.surfaceId,
    required this.child,
  });
  final SurfaceId surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref
        .watch(subsurfaceStatesProvider(surfaceId).select((v) => v.position));

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: child,
    );
  }
}

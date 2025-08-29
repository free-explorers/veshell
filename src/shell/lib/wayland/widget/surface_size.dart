import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

class SurfaceSize extends ConsumerWidget {
  const SurfaceSize({
    required this.surfaceId,
    required this.scaleRatio,
    required this.child,
    super.key,
  });

  final SurfaceId surfaceId;
  final double scaleRatio;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceSize = ref.watch(
      wlSurfaceStateProvider(surfaceId).select(
        (v) => v.texture!.size,
      ),
    );
    return SizedBox(
      width: surfaceSize.width / scaleRatio,
      height: surfaceSize.height / scaleRatio,
      child: child,
    );
  }
}

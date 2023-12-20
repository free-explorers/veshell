import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.provider.dart';

class SurfaceSize extends ConsumerWidget {
  const SurfaceSize({
    required this.surfaceId,
    required this.child,
    super.key,
  });
  final SurfaceId surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceSize = ref
        .watch(wlSurfaceStateProvider(surfaceId).select((v) => v.surfaceSize));

    return SizedBox(
      width: surfaceSize.width,
      height: surfaceSize.height,
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.provider.dart';
import 'package:shell/shared/util/rect_overflow_box.dart';

class ContainToInputRegion extends ConsumerWidget {
  const ContainToInputRegion({
    required this.surfaceId,
    required this.child,
    super.key,
  });
  final SurfaceId surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputRegion = ref
        .watch(wlSurfaceStateProvider(surfaceId).select((v) => v.inputRegion));

    return CropOverflowBox(
      rect: inputRegion,
      child: child,
    );
  }
}

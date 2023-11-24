import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/util/rect_overflow_box.dart';
import 'package:shell/shared/wayland/xdg_surface/xdg_surface.provider.dart';

class ContainToVisibleBounds extends ConsumerWidget {
  const ContainToVisibleBounds({
    required this.viewId,
    required this.child,
    super.key,
  });
  final int viewId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleBounds = ref.watch(
      xdgSurfaceStatesProvider(viewId).select((value) => value.visibleBounds),
    );

    return CropOverflowBox(
      rect: visibleBounds,
      child: child,
    );
  }
}

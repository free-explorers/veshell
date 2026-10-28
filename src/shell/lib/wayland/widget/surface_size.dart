import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

class SurfaceSize extends ConsumerWidget {
  const SurfaceSize({
    required this.surfaceId,
    required this.scaleRatio,
    required this.builder,
    super.key,
  });

  final SurfaceId surfaceId;
  final double scaleRatio;

  /// Builds the surface content laid out at the logical size it is given.
  final Widget Function(BuildContext context, Size logicalSize) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (surfaceSize, bufferScale, viewportSize) = ref.watch(
      wlSurfaceStateProvider(
        surfaceId,
      ).select((v) => (v.texture!.size, v.scale, v.viewportSize)),
    );
    final logicalSize = surfaceLogicalSize(
      surfaceSize,
      bufferScale,
      scaleRatio,
      viewportSize: viewportSize,
    );
    geometryLog.fine(
      'surface layout surface=$surfaceId texture=$surfaceSize '
      'outputScale=$scaleRatio bufferScale=$bufferScale '
      'viewport=$viewportSize '
      'logicalSize=$logicalSize',
    );
    return SizedBox(
      width: logicalSize.width,
      height: logicalSize.height,
      child: builder(context, logicalSize),
    );
  }
}

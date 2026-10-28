import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/physical_pixel_snap.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/subsurface_state.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/widget/subsurface.dart';
import 'package:shell/wayland/widget/surface/view_input_listener.dart';
import 'package:shell/wayland/widget/surface_size.dart';

class SurfaceWidget extends ConsumerWidget {
  const SurfaceWidget({
    required this.surfaceId,
    required this.scaleRatio,
    this.globalOffsetOverride,
    super.key,
  });

  final SurfaceId surfaceId;
  final double scaleRatio;

  /// Native surface origin for pointer mapping, when it is authoritative
  /// (floating X11 windows). See [ViewInputListener.globalOffsetOverride].
  final Offset? globalOffsetOverride;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SurfaceSize(
      surfaceId: surfaceId,
      scaleRatio: scaleRatio,
      builder: (context, logicalSize) => Stack(
        clipBehavior: Clip.none,
        children: [
          _Subsurfaces(
            surfaceId: surfaceId,
            scaleRatio: scaleRatio,
            layer: _SubsurfaceLayer.below,
          ),
          ViewInputListener(
            surfaceId: surfaceId,
            surfaceSize: logicalSize,
            globalOffsetOverride: globalOffsetOverride,
            child: Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                final (textureId, bufferSize, viewportSource) = ref.watch(
                  wlSurfaceStateProvider(surfaceId).select(
                    (v) => (v.texture!.id, v.texture!.size, v.viewportSource),
                  ),
                );
                // Keep the texture on the physical pixel grid: at a
                // fractional scale a whole-logical-pixel origin is not enough
                // to keep the buffer mapped 1:1 (see `PhysicalPixelSnap`).
                return PhysicalPixelSnap(
                  child: ViewportCrop(
                    bufferSize: bufferSize,
                    source: viewportSource,
                    child: Texture(textureId: textureId),
                  ),
                );
              },
            ),
          ),
          _Subsurfaces(
            surfaceId: surfaceId,
            scaleRatio: scaleRatio,
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
    required this.scaleRatio,
    required this.layer,
  });

  final SurfaceId surfaceId;
  final _SubsurfaceLayer layer;
  final double scaleRatio;

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
        .map((id) => SubsurfaceWidget(surfaceId: id, scaleRatio: scaleRatio))
        .toList();

    return subsurfaces.isEmpty
        ? const SizedBox.shrink()
        : Stack(clipBehavior: Clip.none, children: subsurfaces);
  }
}

enum _SubsurfaceLayer { below, above }

/// Shows the `wp_viewport` [source] part of a buffer of [bufferSize] pixels,
/// stretched over the space it is given; the whole buffer without a source.
///
/// The texture is laid out at the size that puts [source] exactly over this
/// widget's box, shifted by the source origin, and clipped.
class ViewportCrop extends StatelessWidget {
  const ViewportCrop({
    required this.bufferSize,
    required this.source,
    required this.child,
    super.key,
  });

  final Size bufferSize;
  final Rect? source;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final source = this.source;
    if (source == null ||
        source.isEmpty ||
        bufferSize.isEmpty ||
        source == Offset.zero & bufferSize) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        final scaleX = box.width / source.width;
        final scaleY = box.height / source.height;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(-source.left * scaleX, -source.top * scaleY),
              child: SizedBox(
                width: bufferSize.width * scaleX,
                height: bufferSize.height * scaleY,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

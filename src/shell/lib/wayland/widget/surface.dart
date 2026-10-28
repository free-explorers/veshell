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

/// Paints the [source] part of a buffer of [bufferSize] pixels (the whole
/// buffer without a `wp_viewport` source) over the box it is given.
///
/// When the shown pixels are within one pixel of the box's physical size, they
/// are painted 1:1 instead of stretched. A fractional-scale client renders a
/// buffer of `round(logical * scale)` pixels: Chromium declares a 1018-pixel
/// window at 1.2 and draws 1222 pixels, while the box is 1221.6 pixels.
/// Stretching by that fraction resamples every pixel and softens all text;
/// painting 1:1 lets the surface overhang its box by under a pixel and stays
/// sharp. A real scale (a 2x buffer shown at 1.25) is still stretched.
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
    if (bufferSize.isEmpty) return child;
    final source = (this.source == null || this.source!.isEmpty)
        ? Offset.zero & bufferSize
        : this.source!;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        double pixelScale(double shown, double extent) =>
            (shown - extent * devicePixelRatio).abs() < 1
            ? 1 / devicePixelRatio
            : extent / shown;
        final scaleX = pixelScale(source.width, box.width);
        final scaleY = pixelScale(source.height, box.height);
        final cropped = source != Offset.zero & bufferSize;
        final texture = OverflowBox(
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
        );
        // Only a crop needs clipping; the 1:1 overhang is under a pixel.
        return cropped ? ClipRect(child: texture) : texture;
      },
    );
  }
}

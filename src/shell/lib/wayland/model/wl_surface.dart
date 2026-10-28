import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:material_ui/material_ui.dart';

part 'wl_surface.freezed.dart';

typedef TextureId = int;
typedef SurfaceId = int;

enum SurfaceRole { xdgToplevel, xdgPopup, subsurface, x11Surface }

@freezed
abstract class SurfaceTexture with _$SurfaceTexture {
  const factory SurfaceTexture({required TextureId id, required Size size}) =
      _SurfaceTexture;
}

@freezed
abstract class WlSurface with _$WlSurface {
  const factory WlSurface({
    required SurfaceId surfaceId,
    required SurfaceRole? role,
    required SurfaceTexture? texture,
    required int scale,
    required IList<int> subsurfacesBelow,
    required IList<int> subsurfacesAbove,
    required Rect inputRegion,

    /// `wp_viewport` destination, when the client set one; see
    /// [surfaceLogicalSize].
    Size? viewportSize,

    /// `wp_viewport` source crop in buffer pixels, when the client set one.
    Rect? viewportSource,
  }) = _WlSurface;
}

/// How many buffer pixels make one logical pixel of a committed surface.
///
/// A client that sets an integer `wl_surface.buffer_scale` above 1 declares
/// its buffer to be exactly that multiple of its logical size; this is what a
/// client without fractional-scale support does on a fractional output
/// (`wl_output.scale` is advertised rounded up, so 2 at 1.25). Every other
/// client (fractional-aware Wayland clients, Xwayland) renders at
/// [scaleRatio] with a buffer scale of 1. Dividing such a 2x buffer by the
/// fractional ratio drew the surface too large, and pointer coordinates, which
/// the client reads in its own logical space, drifted away from what it drew.
double surfaceBufferScale(int bufferScale, double scaleRatio) =>
    bufferScale > 1 ? bufferScale.toDouble() : scaleRatio;

/// A committed surface's size in logical pixels.
///
/// A `wp_viewport` destination ([viewportSize]) is the logical size by
/// definition: fractional-scale clients render at the preferred scale and
/// declare their size with it. Otherwise the buffer is divided by its scale;
/// see [surfaceBufferScale].
Size surfaceLogicalSize(
  Size bufferSize,
  int bufferScale,
  double scaleRatio, {
  Size? viewportSize,
}) {
  if (viewportSize != null) return viewportSize;
  final scale = surfaceBufferScale(bufferScale, scaleRatio);
  return Size(bufferSize.width / scale, bufferSize.height / scale);
}

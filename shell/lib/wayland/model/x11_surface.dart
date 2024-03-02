import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'x11_surface.freezed.dart';

typedef X11SurfaceId = int;

@freezed
class X11Surface with _$X11Surface {
  const factory X11Surface({
    required X11SurfaceId x11SurfaceId,
    required SurfaceId? surfaceId,
  }) = _X11Surface;
}

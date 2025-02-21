import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/x11_surface.dart';

part 'surface_manager_state.freezed.dart';

@freezed
class SurfaceManagerState with _$SurfaceManagerState {
  const factory SurfaceManagerState({
    required ISet<SurfaceId> wlSurfaces,
    required ISet<SurfaceId> xdgTopLevelSurfaces,
    required ISet<SurfaceId> xdgPopupSurfaces,
    required ISet<SurfaceId> subSurfaces,
    required ISet<X11SurfaceId> x11Surfaces,
  }) = _SurfaceManagerState;
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'surface_manager_state.freezed.dart';

@freezed
abstract class SurfaceManagerState with _$SurfaceManagerState {
  const factory SurfaceManagerState({
    required ISet<SurfaceId> wlSurfaces,
    required ISet<SurfaceId> subSurfaces,
  }) = _SurfaceManagerState;
}

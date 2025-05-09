import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'meta_window_id_per_surface_id.g.dart';

@riverpod
class MetaWindowIdPerSurfaceId extends _$MetaWindowIdPerSurfaceId {
  KeepAliveLink? _keepAliveLink;

  @override
  MetaWindowId? build(SurfaceId surfaceId) {
    return null;
  }

  void set(MetaWindowId metaWindowId) {
    _keepAliveLink?.close();
    _keepAliveLink = ref.keepAlive();
    state = metaWindowId;
  }

  void clear() {
    _keepAliveLink?.close();
  }
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';

part 'meta_window_window_map.g.dart';

@Riverpod(keepAlive: true)
class MetaWindowWindowMap extends _$MetaWindowWindowMap {
  @override
  IMap<MetaWindowId, WindowId> build() {
    return IMap();
  }

  void set(MetaWindowId metaWindowId, WindowId windowId) {
    state = state.add(metaWindowId, windowId);
  }

  void unset(MetaWindowId metaWindowId) {
    state = state.remove(metaWindowId);
  }
}

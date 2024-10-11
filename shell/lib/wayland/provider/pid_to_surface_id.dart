import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pid_to_surface_id.g.dart';

@Riverpod(keepAlive: true)
class PidToSurfaceId extends _$PidToSurfaceId {
  @override
  IMap<int, int> build() {
    return <int, int>{}.lock;
  }

  void setPid(int pid, int surfaceId) {
    state = state.add(pid, surfaceId);
  }
}

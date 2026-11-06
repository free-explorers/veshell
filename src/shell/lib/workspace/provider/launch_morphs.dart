import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/model/launch_morph_request.dart';

part 'launch_morphs.g.dart';

/// The tiles opening with a launch morph, by window: the launcher registers
/// the launch as it creates the tile, the tile plays it and clears it.
@Riverpod(keepAlive: true)
class LaunchMorphs extends _$LaunchMorphs {
  @override
  IMap<PersistentWindowId, LaunchMorphRequest> build() => const IMapConst({});

  void start(PersistentWindowId windowId, LaunchMorphRequest request) {
    state = state.add(windowId, request);
  }

  /// The morph of [windowId] is over (or abandoned).
  void finish(PersistentWindowId windowId) {
    if (state.containsKey(windowId)) {
      state = state.remove(windowId);
    }
  }
}

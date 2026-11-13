import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

part 'paused_game_surfaces.g.dart';

/// The surfaces of the game-mode windows that are not active (paused), wherever
/// their tile is: the compositor paces them down even on a workspace that is
/// not shown, where their tile is not mounted to report them.
@riverpod
ISet<int> pausedGameSurfaces(Ref ref) {
  final windows = ref.watch(windowManagerProvider.select((s) => s.windows));
  final surfaces = <int>{};
  for (final id in windows.whereType<PersistentWindowId>()) {
    final (mode, metaWindowId) = ref.watch(
      persistentWindowStateProvider(
        id,
      ).select((window) => (window.displayMode, window.metaWindowId)),
    );
    if (mode != DisplayMode.game || metaWindowId == null) continue;
    // A tile can briefly outlive its window; see `WindowWidget`.
    try {
      final (active, surfaceId) = ref.watch(
        metaWindowStateProvider(
          metaWindowId,
        ).select((window) => (window.gameModeActivated, window.surfaceId)),
      );
      if (!active) surfaces.add(surfaceId);
    } on Object {
      continue;
    }
  }
  return surfaces.lock;
}

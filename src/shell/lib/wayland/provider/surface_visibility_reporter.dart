import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/request/surface_visibility/surface_visibility.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/wayland/provider/paused_game_surfaces.dart';
import 'package:shell/wayland/widget/surface_visibility.dart';

part 'surface_visibility_reporter.g.dart';

/// Reports to the compositor which client surfaces the shell displays (see
/// [SurfaceVisibilityTracker]), so it paces the frame callbacks of hidden
/// windows and paused games down. Alive for the session: the app root
/// listens to it from startup.
@riverpod
void surfaceVisibilityReporter(Ref ref) {
  ref.listen(
    pausedGameSurfacesProvider,
    (_, surfaces) =>
        SurfaceVisibilityTracker.instance.pausedGames = surfaces.unlock,
    fireImmediately: true,
  );
  SurfaceVisibilityTracker.instance.start((visible, limited) {
    unawaited(
      ref
          .read(platformManagerProvider.notifier)
          .request(
            SurfaceVisibilityRequest(
              message: SurfaceVisibilityMessage(
                visible: visible,
                limited: limited,
              ),
            ),
          ),
    );
  });
}

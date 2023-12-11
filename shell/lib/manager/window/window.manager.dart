import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'window.manager.g.dart';

class WindowManagerState {
  const WindowManagerState({required this.toplevelList});
  final List<num> toplevelList;
}

@Riverpod(keepAlive: true)
class WindowManager extends _$WindowManager {
  @override
  WindowManagerState build() {
    /* final api = ref.watch(platformApiProvider);
    api. */
    return const WindowManagerState(toplevelList: []);
  }
}

/* @riverpod
void surfaceCommitHandler(SurfaceCommitHandlerRef ref) {
  ref.listen(waylandManagerProvider, (_, next) {
    if (next case AsyncData(value: final DestroySurfaceEvent event)) {
      // do something when this event occurs
    }
  });

  return;
} */

/* @riverpod
Future<DestroySurfaceEvent> destroySurfaceEvents(DestroySurfaceEventRef ref) {
  ref.listen(
    waylandManagerProvider,
    (_, next) {
      if (next case AsyncData(value: final DestroySurfaceEvent event)) {
        ref.state = AsyncData(event);
      }
    },
    fireImmediately: true,
  );
  // stay in loading until that^ trigers
  return ref.future;
} */

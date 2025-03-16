import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/provider/persistent_window_state.dart';

part 'matching_info_for_window.g.dart';

@Riverpod(keepAlive: true)
class MatchingInfoForWindow extends _$MatchingInfoForWindow {
  @override
  MatchingInfo build(PersistentWindowId windowId) {
    print('MatchingInfoForWindow.build $windowId');
    final persistentWindow = ref.read(persistentWindowStateProvider(windowId));
    return MatchingInfo.fromWindowProperties(persistentWindow.properties);
  }

  void startMatching(int? pid) {
    state = state.copyWith(
      waitingForAppSince: DateTime.now(),
      pid: pid,
    );
  }

  void matched({required bool matchedWhileWaiting}) {
    state = state.copyWith(
      matchedAtTime: DateTime.now(),
      matchedWhileWaiting: matchedWhileWaiting,
    );
  }

  void reset() {
    ref.invalidateSelf();
  }
}

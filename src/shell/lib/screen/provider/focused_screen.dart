import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_manager.dart';

part 'focused_screen.g.dart';

/// Provide the current Focused screen, or `null` while no screen exists.
@riverpod
class FocusedScreen extends _$FocusedScreen {
  @override
  ScreenId? build() {
    final screenIds = ref.watch(
      screenManagerProvider.select((value) => value.screenIds),
    );
    if (screenIds.isEmpty) {
      return null;
    }

    final current = stateOrNull;
    if (current != null && screenIds.contains(current)) {
      return current;
    }
    return screenIds.first;
  }

  void setFocusedScreen(ScreenId? screenId) {
    if (screenId == null) {
      state = null;
      return;
    }
    if (!ref.read(screenManagerProvider).screenIds.contains(screenId)) {
      return;
    }
    state = screenId;
  }
}

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.dart';

part 'focused_screen.g.dart';

/// Provide the current Focused screen
@riverpod
class FocusedScreen extends _$FocusedScreen {
  @override
  ScreenId? build() {
    return null;
  }

  setFocusedScreen(ScreenId? screenId) {
    state = screenId;
  }
}

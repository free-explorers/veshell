import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_list.dart';

part 'focused_screen.g.dart';

/// Provide the current Focused screen
@riverpod
class FocusedScreen extends _$FocusedScreen {
  @override
  ScreenId build() {
    return ref.read(screenListProvider).first;
  }

  setFocusedScreen(ScreenId screenId) {
    state = screenId;
  }
}

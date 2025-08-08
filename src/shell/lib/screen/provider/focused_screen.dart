import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_manager.dart';

part 'focused_screen.g.dart';

/// Provide the current Focused screen
@riverpod
class FocusedScreen extends _$FocusedScreen {
  @override
  ScreenId build() {
    return ref
        .read(
          screenManagerProvider.select(
            (value) => value.screenIds,
          ),
        )
        .first;
  }

  void setFocusedScreen(ScreenId screenId) {
    state = screenId;
  }
}

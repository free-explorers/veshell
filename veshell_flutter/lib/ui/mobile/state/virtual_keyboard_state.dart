import 'package:flutter/rendering.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/platform_api.dart';

part '../../../generated/ui/mobile/state/virtual_keyboard_state.freezed.dart';

part '../../../generated/ui/mobile/state/virtual_keyboard_state.g.dart';

@riverpod
class VirtualKeyboardStateNotifier extends _$VirtualKeyboardStateNotifier {
  @override
  VirtualKeyboardState build(int viewId) {
    ref.listen(textInputEventStreamProvider(viewId), (_, data) {
      data.whenData((event) {
        if (event is TextInputEnable || event is TextInputCommit) {
          activated = true;
        } else if (event is TextInputDisable) {
          activated = false;
        }
      });
    });

    return const VirtualKeyboardState(
      activated: false,
      size: Size.zero,
    );
  }

  set activated(bool value) {
    state = state.copyWith(activated: value);
  }

  set size(Size value) {
    state = state.copyWith(size: value);
  }
}

@freezed
class VirtualKeyboardState with _$VirtualKeyboardState {
  const factory VirtualKeyboardState({
    required bool activated,
    required Size size,
  }) = _VirtualKeyboardState;
}

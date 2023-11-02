import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/util/state/root_overlay.dart';
import 'package:zenith/ui/mobile/power_menu.dart';

part '../../../generated/ui/mobile/state/power_menu_state.freezed.dart';

part '../../../generated/ui/mobile/state/power_menu_state.g.dart';

@Riverpod(keepAlive: true)
class PowerMenuStateNotifier extends _$PowerMenuStateNotifier {
  @override
  PowerMenuState build() {
    return PowerMenuState(
      overlayEntry: OverlayEntry(builder: (_) => const PowerMenu()),
      overlayEntryInserted: false,
      shown: false,
      show: Object(),
      hide: Object(),
    );
  }

  void show() {
    if (!state.overlayEntryInserted) {
      ref.read(rootOverlayKeyProvider).currentState?.insert(state.overlayEntry);
    }
    state = state.copyWith(
      overlayEntryInserted: true,
      show: Object(),
      shown: true,
    );
  }

  /// Starts the unlock animation. The Widget must listen to this event.
  void hide() {
    state = state.copyWith(
      hide: Object(),
      shown: false,
    );
  }

  /// The Widget is responsible to call this method after the unlock animation is complete.
  void removeOverlay() {
    if (state.overlayEntryInserted) {
      state.overlayEntry.remove();
      state = state.copyWith(
        overlayEntryInserted: false,
        shown: false,
      );
    }
  }
}

@freezed
class PowerMenuState with _$PowerMenuState {
  const factory PowerMenuState({
    required OverlayEntry overlayEntry,
    required bool overlayEntryInserted,
    required bool shown,
    required Object show,
    required Object hide,
  }) = _PowerMenuState;
}

import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/platform_api.dart';
import 'package:zenith/util/state/display_brightness_state.dart';
import 'package:zenith/util/state/lock_screen_state.dart';

part '../../generated/util/state/screen_state.freezed.dart';

part '../../generated/util/state/screen_state.g.dart';

@Riverpod(keepAlive: true)
class ScreenStateNotifier extends _$ScreenStateNotifier {
  @override
  ScreenState build() {
    return const ScreenState(
      on: true,
      pending: false,
      size: Size.zero,
      rotation: 0,
      rotatedSize: Size.zero,
    );
  }

  Future<void> turnOff() async {
    if (!state.on || state.pending) {
      return;
    }

    state = state.copyWith(pending: true);

    final displayBrightnessState = ref.read(displayBrightnessStateProvider);
    final displayBrightnessStateNotifier = ref.read(displayBrightnessStateProvider.notifier);

    if (displayBrightnessState.available) {
      displayBrightnessStateNotifier.saveBrightness();

      // There's a good reason we do these things in this order.
      // After turning off the screen, we wait one single frame to give the lock screen the opportunity to render
      // itself before we turn off rendering. The user will only see the lock screen when he turns the screen back on.
      try {
        // Multiple things can go wrong, the reason for this try-catch.
        // We might not have permission to write to the brightness file even if the file exists.
        await displayBrightnessStateNotifier.setBrightness(0);
        state = state.copyWith(on: false);

        SchedulerBinding.instance.addPostFrameCallback((_) async {
          try {
            await ref.read(platformApiProvider.notifier).enableDisplay(false);
          } catch (_) {}

          state = state.copyWith(pending: false);
        });
      } catch (_) {
        state = state.copyWith(pending: false);
      }
    }
  }

  Future<void> lockAndTurnOff() {
    ref.read(lockScreenStateProvider.notifier).lock();
    return turnOff();
  }

  Future<void> turnOn() async {
    if (state.on || state.pending) {
      return;
    }

    state = state.copyWith(pending: true);

    final displayBrightnessState = ref.read(displayBrightnessStateProvider);
    final displayBrightnessStateNotifier = ref.read(displayBrightnessStateProvider.notifier);

    if (displayBrightnessState.available) {
      try {
        await ref.read(platformApiProvider.notifier).enableDisplay(true);

        SchedulerBinding.instance.addPostFrameCallback((_) async {
          try {
            await displayBrightnessStateNotifier.restoreBrightness();
            state = state.copyWith(on: true);
          } catch (_) {}

          state = state.copyWith(pending: false);
        });
      } catch (_) {
        state = state.copyWith(pending: false);
      }
    }
  }

  void rotateClockwise() {
    state = state.copyWith(rotation: (state.rotation + 1) % 4);
  }

  void rotateCounterclockwise() {
    state = state.copyWith(rotation: (state.rotation - 1) % 4);
  }

  void setRotation(int quarterTurns) {
    state = state.copyWith(rotation: quarterTurns);
  }

  void setSize(Size size) {
    state = state.copyWith(size: size);
  }

  void setRotatedSize(Size rotatedSize) {
    state = state.copyWith(rotatedSize: rotatedSize);
  }
}

@freezed
class ScreenState with _$ScreenState {
  const factory ScreenState({
    required bool on,

    /// Turn on/off operations have not yet finished.
    required bool pending,

    /// Rotation expressed in clockwise quarter turns.
    required int rotation,

    /// The screen size, before rotation.
    required Size size,

    /// The screen size, after rotation.
    /// If the physical screen is 500x1000 in portrait and the device is rotated in landscape, this
    /// variable contains the size 1000x500.
    required Size rotatedSize,
  }) = _ScreenState;
}

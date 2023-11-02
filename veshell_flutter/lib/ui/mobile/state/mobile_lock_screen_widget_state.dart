import 'package:flutter/cupertino.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/mobile/lock_screen.dart';
import 'package:zenith/util/state/lock_screen_state.dart';
import 'package:zenith/util/state/root_overlay.dart';

part '../../../generated/ui/mobile/state/mobile_lock_screen_widget_state.freezed.dart';

part '../../../generated/ui/mobile/state/mobile_lock_screen_widget_state.g.dart';

@Riverpod(keepAlive: true)
class MobileLockScreenState extends _$MobileLockScreenState {
  @override
  MobileLockScreenWidgetState build() {
    ref.listen(lockScreenStateProvider.select((v) => v.lock), (_, __) {
      _lock();
    });

    return MobileLockScreenWidgetState(
      overlayEntry: OverlayEntry(builder: (_) => const LockScreen()),
      // The session starts locked. If you change these to false, also modify `initialEntries` of the Overlay widget.
      overlayEntryInserted: false,
      dragging: false,
      dragVelocity: 0.0,
      offset: 0.0,
      slideDistance: 300.0,
    );
  }

  void startDrag() {
    state = state.copyWith(
      dragging: true,
    );
  }

  void drag(double offset) {
    state = state.copyWith(
      offset: (state.offset + offset).clamp(0, state.slideDistance),
    );
  }

  set offset(double offset) {
    state = state.copyWith(
      offset: offset,
    );
  }

  void endDrag(double velocity) {
    state = state.copyWith(
      dragging: false,
      dragVelocity: velocity,
    );
  }

  void _lock() {
    if (!state.overlayEntryInserted) {
      ref
          .read(rootOverlayKeyProvider)
          .currentState
          ?.insert(state.overlayEntry);
    }
    state = state.copyWith(
      overlayEntryInserted: true,
      dragging: false,
      dragVelocity: 0.0,
      offset: 0.0,
    );
  }

  /// The Widget is responsible to call this method after the unlock animation is complete.
  void removeOverlay() {
    state.overlayEntry.remove();
    state = state.copyWith(
      overlayEntryInserted: false,
    );
  }
}

@freezed
class MobileLockScreenWidgetState with _$MobileLockScreenWidgetState {
  const factory MobileLockScreenWidgetState({
    required OverlayEntry overlayEntry,
    required bool overlayEntryInserted,
    required bool dragging,
    required double dragVelocity,
    required double offset,
    required double slideDistance,
  }) = _MobileLockScreenWidgetState;
}

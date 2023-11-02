import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/common/popup.dart';
import 'package:zenith/ui/common/state/xdg_surface_state.dart';

part '../../../generated/ui/common/state/xdg_popup_state.freezed.dart';

part '../../../generated/ui/common/state/xdg_popup_state.g.dart';

@Riverpod(keepAlive: true)
Popup popupWidget(PopupWidgetRef ref, int viewId) {
  return Popup(
    key: ref.watch(xdgSurfaceStatesProvider(viewId).select((state) => state.widgetKey)),
    viewId: viewId,
  );
}

@freezed
class XdgPopupState with _$XdgPopupState {
  const factory XdgPopupState({
    required int parentViewId,
    required Offset position,
    required GlobalKey<AnimationsState> animationsKey,
    required bool isClosing,
  }) = _XdgPopupState;
}

@Riverpod(keepAlive: true)
class XdgPopupStates extends _$XdgPopupStates {
  @override
  XdgPopupState build(int viewId) {
    return XdgPopupState(
      parentViewId: -1,
      position: Offset.zero,
      animationsKey: GlobalKey<AnimationsState>(),
      isClosing: false,
    );
  }

  void commit({
    required int parentViewId,
    required Offset position,
  }) {
    state = state.copyWith(
      parentViewId: parentViewId,
      position: position,
    );
  }

  set parentViewId(int value) {
    state = state.copyWith(parentViewId: value);
  }

  set position(Offset value) {
    state = state.copyWith(position: value);
  }

  Future? animateClosing() async {
    state = state.copyWith(isClosing: true);
    await state.animationsKey.currentState?.controller.reverse();
    state = state.copyWith(isClosing: false);
  }

  TickerFuture? cancelClosingAnimation() {
    state = state.copyWith(isClosing: false);
    return state.animationsKey.currentState?.controller.forward();
  }

  void dispose() {
    ref.invalidate(popupWidgetProvider(viewId));
    ref.invalidate(xdgPopupStatesProvider(viewId));
  }
}

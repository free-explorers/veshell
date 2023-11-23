import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/wayland/xdg_popup/popup.dart';
import 'package:shell/shared/wayland/xdg_popup/xdg_popup.model.dart';
import 'package:shell/shared/wayland/xdg_surface/xdg_surface.provider.dart';

part 'xdg_popup.provider.g.dart';

@Riverpod(keepAlive: true)
Popup popupWidget(PopupWidgetRef ref, int viewId) {
  return Popup(
    key: ref.watch(
      xdgSurfaceStatesProvider(viewId).select((state) => state.widgetKey),
    ),
    viewId: viewId,
  );
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

@Riverpod(keepAlive: true)
GlobalKey popupStackGlobalKey(PopupStackGlobalKeyRef ref) => GlobalKey();

@Riverpod(keepAlive: true)
class PopupStackChildren extends _$PopupStackChildren {
  @override
  IList<int> build() {
    return IList();
  }

  void add(int viewId) => state = state.add(viewId);

  void remove(int viewId) => state = state.remove(viewId);
}

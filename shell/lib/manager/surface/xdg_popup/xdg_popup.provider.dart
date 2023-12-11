import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/surface/xdg_popup/popup.dart';
import 'package:shell/manager/surface/xdg_popup/xdg_popup.model.dart';
import 'package:shell/manager/surface/xdg_surface/xdg_surface.provider.dart';

part 'xdg_popup.provider.g.dart';

@Riverpod(keepAlive: true)
Popup popupWidget(PopupWidgetRef ref, int surfaceId) {
  return Popup(
    key: ref.watch(
      xdgSurfaceStatesProvider(surfaceId).select((state) => state.widgetKey),
    ),
    surfaceId: surfaceId,
  );
}

@Riverpod(keepAlive: true)
class XdgPopupStates extends _$XdgPopupStates {
  @override
  XdgPopupState build(int surfaceId) {
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
    ref.invalidate(popupWidgetProvider(surfaceId));
    ref.invalidate(xdgPopupStatesProvider(surfaceId));
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

  void add(int surfaceId) => state = state.add(surfaceId);

  void remove(int surfaceId) => state = state.remove(surfaceId);
}

import 'dart:ui';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/xdg_popup.dart';

part 'xdg_popup_state.g.dart';

@riverpod
class XdgPopupState extends _$XdgPopupState {
  late final KeepAliveLink _keepAliveLink;

  @override
  XdgPopup build(SurfaceId surfaceId) {
    throw Exception('XdgPopup $surfaceId state was not initialized');
  }

  void initialize({
    required SurfaceId parent,
    required Offset position,
  }) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing XdgPopupStateProvider $surfaceId');
    });
    state = XdgPopup(
      parent: parent,
      position: position,
    );
  }

  void onCommit({
    required SurfaceId parent,
    required Offset position,
  }) {
    state = state.copyWith(
      parent: parent,
      position: position,
    );
  }

  void setParent(int value) {
    state = state.copyWith(parent: value);
  }

  void dispose() {
    _keepAliveLink.close();
  }
}

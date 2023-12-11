import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/surface/xdg_popup/popup.dart';

part 'xdg_popup.model.freezed.dart';

@freezed
class XdgPopupState with _$XdgPopupState {
  const factory XdgPopupState({
    required int parentViewId,
    required Offset position,
    required GlobalKey<AnimationsState> animationsKey,
    required bool isClosing,
  }) = _XdgPopupState;
}

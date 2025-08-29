import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/util/json_converter/rect.dart';

part 'meta_window_patches.serializable.freezed.dart';
part 'meta_window_patches.serializable.g.dart';

/// Model for MetaWindowPatchMessage
@Freezed(
  unionKey: 'type',
  unionValueCase: FreezedUnionCase.pascal,
)
sealed class MetaWindowPatchMessage
    with _$MetaWindowPatchMessage
    implements PlatformMessage {
  const factory MetaWindowPatchMessage.updateAppId({
    required String id,
    String? value,
  }) = UpdateAppId;

  const factory MetaWindowPatchMessage.updateParent({
    required String id,
    String? value,
  }) = UpdateParent;

  const factory MetaWindowPatchMessage.updateTitle({
    required String id,
    String? value,
  }) = UpdateTitle;

  const factory MetaWindowPatchMessage.updatePid({
    required String id,
    required int value,
  }) = UpdatePid;

  const factory MetaWindowPatchMessage.updateWindowClass({
    required String id,
    String? value,
  }) = UpdateWindowClass;

  const factory MetaWindowPatchMessage.updateStartupId({
    required String id,
    String? value,
  }) = UpdateStartupId;

  const factory MetaWindowPatchMessage.updateDisplayMode({
    required String id,
    MetaWindowDisplayMode? value,
  }) = UpdateDisplayMode;

  const factory MetaWindowPatchMessage.updateMapped({
    required String id,
    required bool value,
  }) = UpdateMapped;

  const factory MetaWindowPatchMessage.updateGeometry({
    required String id,
    @RectConverter() Rect? value,
  }) = UpdateGeometry;

  const factory MetaWindowPatchMessage.updateNeedDecoration({
    required String id,
    required bool value,
  }) = UpdateNeedDecoration;

  const factory MetaWindowPatchMessage.updateGameModeActivated({
    required String id,
    required bool value,
  }) = UpdateGameModeActivated;

  const factory MetaWindowPatchMessage.updateCurrentOutput({
    required String id,
    String? value,
  }) = UpdateCurrentOutput;

  const factory MetaWindowPatchMessage.updateScaleRatio({
    required String id,
    required double value,
  }) = UpdateScaleRatio;

  factory MetaWindowPatchMessage.fromJson(Map<String, dynamic> json) =>
      _$MetaWindowPatchMessageFromJson(json);
}

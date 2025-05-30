import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/wayland.manager.dart';
import 'package:shell/shared/util/json_converter/offset.dart';

part 'meta_popup_patches.serializable.freezed.dart';
part 'meta_popup_patches.serializable.g.dart';

/// Model for MetaPopupPatchMessage
@Freezed(
  unionKey: 'type',
  unionValueCase: FreezedUnionCase.pascal,
)
sealed class MetaPopupPatchMessage
    with _$MetaPopupPatchMessage
    implements WaylandMessage {
  const factory MetaPopupPatchMessage.updatePosition({
    required String id,
    @OffsetConverter() required Offset value,
  }) = UpdatePosition;

  factory MetaPopupPatchMessage.fromJson(Map<String, dynamic> json) =>
      _$MetaPopupPatchMessageFromJson(json);
}

import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/util/json_converter/rect.dart';

part 'meta_window_created.serializable.freezed.dart';
part 'meta_window_created.serializable.g.dart';

/// Model for MetaWindowCreatedMessage
@freezed
sealed class MetaWindowCreatedMessage
    with _$MetaWindowCreatedMessage
    implements PlatformMessage {
  /// Factory
  factory MetaWindowCreatedMessage({
    required String id,
    required int pid,
    required bool mapped,
    required int surfaceId,
    required bool needDecoration,
    required bool gameModeActivated,
    required double scaleRatio,
    String? appId,
    String? parent,
    String? displayMode,
    String? title,
    String? windowClass,
    String? startupId,
    @RectConverter() Rect? geometry,
  }) = _MetaWindowCreatedMessage;

  factory MetaWindowCreatedMessage.fromJson(Map<String, dynamic> json) =>
      _$MetaWindowCreatedMessageFromJson(json);
}

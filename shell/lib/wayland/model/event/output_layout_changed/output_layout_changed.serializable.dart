import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/util/json_converter/rect.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'output_layout_changed.serializable.freezed.dart';

part 'output_layout_changed.serializable.g.dart';

/// Model for OutputLayoutChangedMessage
@freezed
class OutputLayoutChangedMessage
    with _$OutputLayoutChangedMessage
    implements WaylandMessage {
  /// Factory
  factory OutputLayoutChangedMessage({
    required List<Output> outputs,
  }) = _OutputLayoutChangedMessage;

  factory OutputLayoutChangedMessage.fromJson(Map<String, dynamic> json) =>
      _$OutputLayoutChangedMessageFromJson(json);
}

@freezed
class Output with _$Output{
  const factory Output({
    required String name,
    required String description,
    // required double refresh_rate,
    @RectConverter() required Rect geometry,
  }) = _Output;

  factory Output.fromJson(Map<String, dynamic> json) =>
      _$OutputFromJson(json);
}

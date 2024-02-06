import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/util/json_converter/rect.dart';

part 'monitor.serializable.freezed.dart';

part 'monitor.serializable.g.dart';

typedef MonitorId = String;

/// a Monitor represent a physical display device used to render Veshell
@freezed
class Monitor with _$Monitor {
  /// Factory
  const factory Monitor({
    required MonitorId name,
    required String description,
    @RectConverter() required Rect geometry,
  }) = _Monitor;

  factory Monitor.fromJson(Map<String, dynamic> json) =>
      _$MonitorFromJson(json);
}

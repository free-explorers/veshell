import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/util/json_converter/offset.dart';
import 'package:shell/shared/util/json_converter/size.dart';

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
    required PhysicalProperties physicalProperties,
    required double scale,
    @OffsetConverter() required Offset location,
    required Mode? currentMode,
    required Mode? preferredMode,
    required List<Mode> modes,
  }) = _Monitor;

  factory Monitor.fromJson(Map<String, dynamic> json) =>
      _$MonitorFromJson(json);
}

@freezed
class Mode with _$Mode {
  const factory Mode({
    @SizeConverter() required Size size,
    required int refreshRate,
  }) = _Mode;

  factory Mode.fromJson(Map<String, dynamic> json) => _$ModeFromJson(json);
}

@freezed
class PhysicalProperties with _$PhysicalProperties {
  const factory PhysicalProperties({
    @SizeConverter() required Size size,
    required String make,
    required String model,
  }) = _PhysicalProperties;

  factory PhysicalProperties.fromJson(Map<String, dynamic> json) =>
      _$PhysicalPropertiesFromJson(json);
}

import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/shared/util/json_converter/offset.dart';

part 'monitor_setting.serializable.freezed.dart';
part 'monitor_setting.serializable.g.dart';

@freezed
abstract class MonitorSetting with _$MonitorSetting {
  const factory MonitorSetting({
    required Mode mode,
    required double fractionnalScale,
    @OffsetIntConverter() required Offset location,
    @Default(MonitorTransform.normal) MonitorTransform transform,
    String? mirrorOf,
  }) = _MonitorSetting;

  factory MonitorSetting.fromJson(Map<String, dynamic> json) =>
      _$MonitorSettingFromJson(json);
}

/// User-facing display transform of a monitor.
///
/// Mirrors Rust's `MonitorTransform`: the full set of Smithay output
/// transforms, persisted as `"normal"`, `"rotate90"`, `"rotate180"`,
/// `"rotate270"`, `"flipped"`, `"flipped90"`, `"flipped180"` or `"flipped270"`
/// in `monitor/<connector>.json`.
enum MonitorTransform {
  normal,
  rotate90,
  rotate180,
  rotate270,
  flipped,
  flipped90,
  flipped180,
  flipped270,
}

extension MonitorTransformX on MonitorTransform {
  /// Whether the transform swaps the panel's width and height (a quarter turn).
  bool get isTransposed => switch (this) {
    MonitorTransform.normal ||
    MonitorTransform.rotate180 ||
    MonitorTransform.flipped ||
    MonitorTransform.flipped180 => false,
    MonitorTransform.rotate90 ||
    MonitorTransform.rotate270 ||
    MonitorTransform.flipped90 ||
    MonitorTransform.flipped270 => true,
  };

  /// Human-readable label for the settings UI.
  String get label => switch (this) {
    MonitorTransform.normal => 'Normal',
    MonitorTransform.rotate90 => 'Rotate 90°',
    MonitorTransform.rotate180 => 'Rotate 180°',
    MonitorTransform.rotate270 => 'Rotate 270°',
    MonitorTransform.flipped => 'Flipped',
    MonitorTransform.flipped90 => 'Flipped + Rotate 90°',
    MonitorTransform.flipped180 => 'Flipped + Rotate 180°',
    MonitorTransform.flipped270 => 'Flipped + Rotate 270°',
  };
}

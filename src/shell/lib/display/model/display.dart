import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'display.freezed.dart';

/// DISPLAY
/// The digital world of Veshell
/// The root component that contain everything else
/// It's span accross all monitor.

@freezed
abstract class Display with _$Display {
  /// Factory
  const factory Display({
    required Size size,
  }) = _Display;
}

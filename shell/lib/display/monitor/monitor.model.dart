import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'monitor.model.freezed.dart';

/// a Monitor represent a physical display device used to render Veshell
@freezed
class Monitor with _$Monitor {
  /// Factory
  const factory Monitor({required Rect surface}) = _Monitor;
}

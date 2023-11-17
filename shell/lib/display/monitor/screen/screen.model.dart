import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'screen.model.freezed.dart';

/// a Screen represent a portion of a Monitor where we want to render Veshell.
/// Monitor usually contain a single Screen but for ultra-wide monitor
/// it could be usefull to be able to split it in several Screen.
@freezed
class Screen with _$Screen {
  /// Factory
  const factory Screen({required Rect surface}) = _Screen;
}

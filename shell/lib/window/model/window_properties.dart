import 'package:freezed_annotation/freezed_annotation.dart';

part 'window_properties.freezed.dart';

/// Common properties between Wayland and X11 windows.
/// In some places, the shell shouldn't know what window type it is dealing with.
/// For example, the task manager should be able to list all windows, regardless
/// of their type.
@freezed
class WindowPropertiesState with _$WindowPropertiesState {
  const factory WindowPropertiesState({
    required String? appId,
    required String? title,
  }) = _WindowPropertiesState;
}

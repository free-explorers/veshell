import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';

part 'window_properties.serializable.freezed.dart';
part 'window_properties.serializable.g.dart';

/// Common properties between Wayland and X11 windows.
/// In some places, the shell shouldn't know what window type it is dealing with.
/// For example, the task manager should be able to list all windows, regardless
/// of their type.
@freezed
abstract class WindowProperties with _$WindowProperties {
  const factory WindowProperties({
    required String appId,
    int? pid,
    String? title,
    String? windowClass,
    String? startupId,
  }) = _WindowProperties;

  factory WindowProperties.fromMetaWindow(MetaWindow metaWindow) =>
      WindowProperties(
        appId: metaWindow.appId!,
        title: metaWindow.title,
        windowClass: metaWindow.windowClass,
        startupId: metaWindow.startupId,
        pid: metaWindow.pid,
      );

  factory WindowProperties.fromJson(Map<String, dynamic> json) =>
      _$WindowPropertiesFromJson(json);
}

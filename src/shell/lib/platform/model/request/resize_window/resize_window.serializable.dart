import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'resize_window.serializable.freezed.dart';
part 'resize_window.serializable.g.dart';

/// [ResizeWindowRequest]
class ResizeWindowRequest extends PlatformRequest {
  /// constructor
  const ResizeWindowRequest({
    required ResizeWindowMessage super.message,
    super.method = 'resize_window',
  });
}

/// Model for [ResizeWindowMessage]
@freezed
abstract class ResizeWindowMessage
    with _$ResizeWindowMessage
    implements PlatformMessage {
  /// Factory
  factory ResizeWindowMessage({
    required MetaWindowId metaWindowId,
    required int width,
    required int height,
  }) = _ResizeWindowMessage;

  /// Creates a new [ResizeWindowMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [ResizeWindowMessage] instance.
  factory ResizeWindowMessage.fromJson(Map<String, dynamic> json) =>
      _$ResizeWindowMessageFromJson(json);
}

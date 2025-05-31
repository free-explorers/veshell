import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'close_window.serializable.freezed.dart';
part 'close_window.serializable.g.dart';

/// [CloseWindowRequest]
class CloseWindowRequest extends PlatformRequest {
  /// constructor
  const CloseWindowRequest({
    required CloseWindowMessage super.message,
    super.method = 'close_window',
  });
}

/// Model for [CloseWindowMessage]
@freezed
abstract class CloseWindowMessage
    with _$CloseWindowMessage
    implements PlatformMessage {
  /// Factory
  factory CloseWindowMessage({
    required MetaWindowId metaWindowId,
  }) = _CloseWindowMessage;

  /// Creates a new [CloseWindowMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [CloseWindowMessage] instance.
  factory CloseWindowMessage.fromJson(Map<String, dynamic> json) =>
      _$CloseWindowMessageFromJson(json);
}

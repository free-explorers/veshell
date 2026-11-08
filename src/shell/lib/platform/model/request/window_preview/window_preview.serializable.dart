import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'window_preview.serializable.freezed.dart';
part 'window_preview.serializable.g.dart';

/// Binds the last-frame preview of a persistent tile to the window it
/// displays, or clears that binding when the tile stops displaying it.
///
/// The compositor writes the frame to the persistence directory when the
/// window goes away, whether the shell or the application closed it. The
/// placeholder then shows it blurred instead of the application icon.
class WindowPreviewRequest extends PlatformRequest {
  /// constructor
  const WindowPreviewRequest({
    required WindowPreviewMessage super.message,
    super.method = 'window_preview',
  });
}

/// Model for [WindowPreviewMessage]
@freezed
abstract class WindowPreviewMessage
    with _$WindowPreviewMessage
    implements PlatformMessage {
  /// Factory
  factory WindowPreviewMessage({
    required MetaWindowId metaWindowId,
    required String persistentWindowId,
    required bool attach,
  }) = _WindowPreviewMessage;

  /// Creates a new [WindowPreviewMessage] instance from a map.
  factory WindowPreviewMessage.fromJson(Map<String, dynamic> json) =>
      _$WindowPreviewMessageFromJson(json);
}

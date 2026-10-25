import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'start_move_window.serializable.freezed.dart';
part 'start_move_window.serializable.g.dart';

/// [StartMoveWindowRequest]
///
/// Starts a compositor-owned interactive move for a window owned by a floating
/// tile. The compositor follows the pointer and configures the native X11
/// window; the shell renders from the observed position. It is intentionally
/// limited to floating tiles: tiled/maximized windows keep their existing
/// presentation.
class StartMoveWindowRequest extends PlatformRequest {
  /// constructor
  const StartMoveWindowRequest({
    required StartMoveWindowMessage super.message,
    super.method = 'start_move_window',
  });
}

/// Model for [StartMoveWindowMessage]
@freezed
abstract class StartMoveWindowMessage
    with _$StartMoveWindowMessage
    implements PlatformMessage {
  /// Factory
  factory StartMoveWindowMessage({required MetaWindowId metaWindowId}) =
      _StartMoveWindowMessage;

  /// Creates a new [StartMoveWindowMessage] instance from a map.
  factory StartMoveWindowMessage.fromJson(Map<String, dynamic> json) =>
      _$StartMoveWindowMessageFromJson(json);
}

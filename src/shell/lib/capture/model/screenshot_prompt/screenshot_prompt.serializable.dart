import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screenshot_prompt.serializable.freezed.dart';
part 'screenshot_prompt.serializable.g.dart';

/// Model for ScreenshotPromptMessage: the trusted prompt for portal
/// screenshot and color-pick requests (capture specification section
/// 8.4). The prompt never previews the pixels it is going to take.
@freezed
sealed class ScreenshotPromptMessage
    with _$ScreenshotPromptMessage
    implements PlatformMessage {
  /// Factory
  factory ScreenshotPromptMessage({
    required String requestHandle,
    required int consentToken,
    required String appName,
    required String kind,
  }) = _ScreenshotPromptMessage;

  factory ScreenshotPromptMessage.fromJson(Map<String, dynamic> json) =>
      _$ScreenshotPromptMessageFromJson(json);
}

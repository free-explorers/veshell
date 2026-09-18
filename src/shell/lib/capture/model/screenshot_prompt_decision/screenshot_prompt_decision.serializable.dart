import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screenshot_prompt_decision.serializable.freezed.dart';
part 'screenshot_prompt_decision.serializable.g.dart';

/// [ScreenshotPromptDecisionRequest]
class ScreenshotPromptDecisionRequest extends PlatformRequest {
  /// constructor
  const ScreenshotPromptDecisionRequest({
    required ScreenshotPromptDecisionMessage super.message,
    super.method = 'screenshot_prompt_decision',
  });
}

/// Model for [ScreenshotPromptDecisionMessage]
@freezed
sealed class ScreenshotPromptDecisionMessage
    with _$ScreenshotPromptDecisionMessage
    implements PlatformMessage {
  /// Factory
  factory ScreenshotPromptDecisionMessage({
    required int consentToken,
    required ScreenshotPromptDecisionOutcome outcome,
  }) = _ScreenshotPromptDecisionMessage;

  factory ScreenshotPromptDecisionMessage.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$ScreenshotPromptDecisionMessageFromJson(json);
}

/// What the user decided in the screenshot prompt.
enum ScreenshotPromptDecisionOutcome {
  /// The user allowed the request.
  approved,

  /// The user dropped the flow.
  cancelled;
}

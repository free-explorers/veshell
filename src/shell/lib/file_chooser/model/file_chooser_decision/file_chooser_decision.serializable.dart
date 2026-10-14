import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'file_chooser_decision.serializable.freezed.dart';
part 'file_chooser_decision.serializable.g.dart';

/// [FileChooserDecisionRequest]
class FileChooserDecisionRequest extends PlatformRequest {
  /// constructor
  const FileChooserDecisionRequest({
    required FileChooserDecisionMessage super.message,
    super.method = 'file_chooser_decision',
  });
}

/// Model for [FileChooserDecisionMessage]
@freezed
sealed class FileChooserDecisionMessage
    with _$FileChooserDecisionMessage
    implements PlatformMessage {
  /// Factory
  factory FileChooserDecisionMessage({
    required int consentToken,
    required FileChooserDecisionOutcome outcome,
    @Default(<String>[]) List<String> uris,
  }) = _FileChooserDecisionMessage;

  /// Decode
  factory FileChooserDecisionMessage.fromJson(Map<String, dynamic> json) =>
      _$FileChooserDecisionMessageFromJson(json);
}

/// What the user decided in the file chooser.
enum FileChooserDecisionOutcome {
  /// The user confirmed the selection; [FileChooserDecisionMessage.uris]
  /// carries the chosen `file://` URI(s).
  approved,

  /// The user dropped the flow.
  cancelled,
}

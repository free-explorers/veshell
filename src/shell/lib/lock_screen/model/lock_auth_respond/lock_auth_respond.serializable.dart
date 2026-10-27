import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'lock_auth_respond.serializable.freezed.dart';
part 'lock_auth_respond.serializable.g.dart';

/// Answers the lock screen's pending PAM prompt.
class LockAuthRespondRequest extends PlatformRequest {
  /// constructor
  const LockAuthRespondRequest({
    required LockAuthRespondMessage super.message,
    super.method = 'lock_auth_respond',
  });
}

/// Model for [LockAuthRespondMessage]
///
/// [response] is usually the user's password: [toString] never prints it.
@freezed
abstract class LockAuthRespondMessage
    with _$LockAuthRespondMessage
    implements PlatformMessage {
  /// Factory
  factory LockAuthRespondMessage({required String response}) =
      _LockAuthRespondMessage;

  const LockAuthRespondMessage._();

  factory LockAuthRespondMessage.fromJson(Map<String, dynamic> json) =>
      _$LockAuthRespondMessageFromJson(json);

  @override
  String toString() => 'LockAuthRespondMessage(response: <redacted>)';
}

import 'package:shell/platform/model/request/platform_request.dart';

/// [ShellReadyRequest]
class ShellReadyRequest extends PlatformRequest {
  ///
  const ShellReadyRequest({
    super.method = 'shell_ready',
  });
}

import 'package:shell/platform/provider/platform_manager.dart';

/// Abstract class for a wayland request
///
/// This class is used to create a request to the wayland compositor.
abstract class PlatformRequest implements PlatformInteraction {
  /// Factory
  const PlatformRequest({
    required this.method,
    this.message,
  });

  /// Request Method
  @override
  final String method;

  /// Request Message
  @override
  final PlatformMessage? message;
}

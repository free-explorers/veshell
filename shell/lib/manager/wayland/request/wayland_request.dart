import 'package:shell/manager/wayland/wayland.manager.dart';

/// Abstract class for a wayland request
///
/// This class is used to create a request to the wayland compositor.
abstract class WaylandRequest implements WaylandInteraction {
  /// Factory
  const WaylandRequest({
    required this.method,
    this.message,
  });

  /// Request Method
  @override
  final String method;

  /// Request Message
  @override
  final WaylandMessage? message;
}

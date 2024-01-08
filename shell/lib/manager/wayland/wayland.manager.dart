import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/wayland/event/wayland_event.model.serializable.dart';
import 'package:shell/manager/wayland/request/wayland_request.dart';

part 'wayland.manager.g.dart';

/// Manager for Wayland interaction
///
/// provide a stream of [WaylandEvent]
/// and a method to send [WaylandRequest]
@Riverpod(keepAlive: true)
class WaylandManager extends _$WaylandManager {
  final _channel = const MethodChannel('platform');
  final _streamController = StreamController<WaylandEvent>();

  /// Build the stream of [WaylandEvent]
  @override
  Stream<WaylandEvent> build() {
    _channel.setMethodCallHandler((call) async {
      // try catch to be notified of errors since errors occuring
      // in setMethodCallHandler seem to be outside zone
      try {
        _streamController.sink.add(
          WaylandEvent.fromJson({
            'method': call.method,
            'message': (call.arguments as Map).cast<String, dynamic>(),
          }),
        );
      } catch (e, stackTrace) {
        print(e);
        print(stackTrace);
        rethrow;
      }
    });
    return _streamController.stream;
  }

  /// Send a [WaylandRequest] to the Wayland compositor
  Future<void> request(WaylandRequest request) async {
    await _channel.invokeMethod(request.method, request.message?.toJson());
  }
}

/// base class for a wayland interaction
/// implemented by [WaylandEvent] and [WaylandRequest]
abstract class WaylandInteraction {
  /// Factory
  const WaylandInteraction({
    required this.method,
    required this.message,
  });

  /// interaction Method
  final String method;

  /// interaction Message
  final WaylandMessage? message;
}

/// base class for serializable wayland message
/// ignore: one_member_abstracts
abstract class WaylandMessage {
  /// interaction message need to be serializable
  Map<String, dynamic> toJson();
}

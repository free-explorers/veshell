import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/event/wayland_event.serializable.dart';
import 'package:shell/platform/model/request/wayland_request.dart';

part 'wayland.manager.g.dart';

/// Manager for Wayland interaction
///
/// provide a stream of [WaylandEvent]
/// and a method to send [WaylandRequest]
@riverpod
class WaylandManager extends _$WaylandManager {
  /// Build the stream of [WaylandEvent]
  @override
  Raw<Stream<WaylandEvent>> build() {
    const channel = MethodChannel('platform', JSONMethodCodec());
    final streamCtroller = StreamController<WaylandEvent>.broadcast();
    channel.setMethodCallHandler((call) async {
      // try catch to be notified of errors since errors occuring
      // in setMethodCallHandler seem to be outside zone
      final event = WaylandEvent.fromJson({
        'method': call.method,
        'message': (call.arguments as Map).cast<String, dynamic>(),
      });
      streamCtroller.sink.add(
        event,
      );
    });

    ref.onCancel(() {
      print('paused');
    });
    ref.onResume(() {
      print('resumed');
    });

    return streamCtroller.stream;
  }

  /// Send a [WaylandRequest] to the Wayland compositor
  Future<void> request(WaylandRequest request) async {
    const channel = MethodChannel('platform', JSONMethodCodec());
    await channel.invokeMethod(request.method, request.message?.toJson());
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

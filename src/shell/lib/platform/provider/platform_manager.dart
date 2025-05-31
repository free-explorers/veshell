import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';

part 'platform_manager.g.dart';

/// Manager for Wayland interaction
///
/// provide a stream of [PlatformEvent]
/// and a method to send [PlatformRequest]
@riverpod
class PlatformManager extends _$PlatformManager {
  /// Build the stream of [PlatformEvent]
  @override
  Raw<Stream<PlatformEvent>> build() {
    const channel = MethodChannel('platform', JSONMethodCodec());
    final streamCtroller = StreamController<PlatformEvent>.broadcast();
    channel.setMethodCallHandler((call) async {
      // try catch to be notified of errors since errors occuring
      // in setMethodCallHandler seem to be outside zone
      final event = PlatformEvent.fromJson({
        'method': call.method,
        'message': (call.arguments as Map).cast<String, dynamic>(),
      });
      streamCtroller.sink.add(
        event,
      );
    });

    return streamCtroller.stream;
  }

  /// Send a [PlatformRequest] to the Wayland compositor
  Future<void> request(PlatformRequest request) async {
    const channel = MethodChannel('platform', JSONMethodCodec());
    await channel.invokeMethod(request.method, request.message?.toJson());
  }
}

/// base class for a wayland interaction
/// implemented by [PlatformEvent] and [PlatformRequest]
abstract class PlatformInteraction {
  /// Factory
  const PlatformInteraction({
    required this.method,
    required this.message,
  });

  /// interaction Method
  final String method;

  /// interaction Message
  final PlatformMessage? message;
}

/// base class for serializable wayland message
/// ignore: one_member_abstracts
abstract class PlatformMessage {
  /// interaction message need to be serializable
  Map<String, dynamic> toJson();
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/shared/util/logger.dart';

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
      if (event is CommitSurfaceEvent) {
        final message = event.message;
        geometryLog.fine(
          'platform commit_surface surface=${message.surfaceId} '
          'texture=${message.textureId} buffer=${message.bufferSize} '
          'scale=${message.scale} role=${message.role} '
          'below=${message.subsurfacesBelow} above=${message.subsurfacesAbove}',
        );
      }
      streamCtroller.sink.add(event);
    });

    return streamCtroller.stream;
  }

  /// Send a [PlatformRequest] to the Wayland compositor
  Future<void> request(PlatformRequest request) async {
    const channel = MethodChannel('platform', JSONMethodCodec());
    await channel.invokeMethod(request.method, request.message?.toJson());
  }

  /// Fetch the environment the compositor exposes to launched applications.
  ///
  /// Tracked launches go through the systemd user manager, which does not
  /// inherit the compositor's environment, so the values must be fetched on
  /// demand and forwarded explicitly.
  Future<Map<String, String>> fetchLaunchEnvironment() async {
    const channel = MethodChannel('platform', JSONMethodCodec());
    final response = await channel.invokeMapMethod<dynamic, dynamic>(
      'get_environment_variables',
      const <String, dynamic>{},
    );
    final variables = response?['environmentVariables'];
    if (variables is! Map) {
      return const {};
    }
    return {
      for (final entry in variables.entries)
        if (entry.value is String) entry.key as String: entry.value as String,
    };
  }
}

/// base class for a wayland interaction
/// implemented by [PlatformEvent] and [PlatformRequest]
abstract class PlatformInteraction {
  /// Factory
  const PlatformInteraction({required this.method, required this.message});

  /// interaction Method
  final String method;

  /// interaction Message
  final PlatformMessage? message;
}

/// base class for serializable wayland message
abstract class PlatformMessage {
  /// interaction message need to be serializable
  Map<String, dynamic> toJson();
}

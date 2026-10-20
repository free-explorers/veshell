import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/shared/util/logger.dart';

part 'platform_manager.g.dart';

/// Compositor errors that mean the target of a request was torn down before
/// the request arrived. They are expected during window/surface teardown and
/// are safe to drop.
const _goneInteractionCodes = {
  'surface_doesnt_exist',
  'meta_window_doesnt_exist',
  'toplevel_doesnt_exist',
  'x11_surface_doesnt_exist',
};

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
    try {
      await channel.invokeMethod(request.method, request.message?.toJson());
    } on PlatformException catch (error) {
      // A window can disappear between the shell deciding to send a request
      // and the compositor handling it: a client crash destroys its surface
      // (and unhandled `surface_doesnt_exist` errors used to escape from every
      // fire-and-forget activation/resize/close). The request is stale, not a
      // failure: the next event/render removes the tile's reference.
      if (!_goneInteractionCodes.contains(error.code)) {
        rethrow;
      }
      platformLog.fine(
        '${request.method} dropped for a gone window/surface: '
        '${error.code} ${error.message}',
      );
    }
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

  /// Fetch the keyboard layouts and variants the compositor can compile, read
  /// from libxkbregistry. Each entry has `layout`, `variant`, `brief`,
  /// `description`, `iso639` and `iso3166`.
  Future<List<Map<String, dynamic>>> fetchKeyboardLayouts() async {
    const channel = MethodChannel('platform', JSONMethodCodec());
    final response = await channel.invokeMapMethod<dynamic, dynamic>(
      'get_keyboard_layouts',
      const <String, dynamic>{},
    );
    final layouts = response?['layouts'];
    if (layouts is! List) {
      return const [];
    }
    return [
      for (final layout in layouts)
        if (layout is Map) layout.cast<String, dynamic>(),
    ];
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

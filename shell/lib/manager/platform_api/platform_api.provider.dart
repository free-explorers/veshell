import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/platform_api/platform_event.model.serializable.dart';
import 'package:shell/manager/surface/xdg_toplevel/xdg_toplevel.provider.dart';
import 'package:shell/shared/tasks/tasks.provider.dart';

part 'platform_api.provider.g.dart';

@Riverpod(keepAlive: true)
class WindowMappedStream extends _$WindowMappedStream {
  @override
  Stream<int> build() => ref.watch(platformApiProvider).windowMappedStream;
}

@Riverpod(keepAlive: true)
class WindowUnmappedStream extends _$WindowUnmappedStream {
  @override
  Stream<int> build() => ref.watch(platformApiProvider).windowUnmappedStream;
}

@Riverpod(keepAlive: true)
Stream<dynamic> _textInputEventStreamById(
  _TextInputEventStreamByIdRef ref,
  int surfaceId,
) {
  return ref
      .watch(platformApiProvider)
      .textInputEventsStream
      .where((event) => event.surfaceId == surfaceId);
}

@Riverpod(keepAlive: true)
Future<TextInputEventType> textInputEventStream(
  TextInputEventStreamRef ref,
  int surfaceId,
) async {
  final dynamic event =
      await ref.watch(_textInputEventStreamByIdProvider(surfaceId).future);
  switch (event.runtimeType) {
    case EnableTextInputEvent:
      return TextInputEnable();
    case DisableTextInputEvent:
      return TextInputDisable();
    case CommitTextInputEvent:
      return TextInputCommit();
    default:
      throw ArgumentError.value(
        event,
        "Must be 'enable', 'disable', or 'commit'",
        "event['type']",
      );
  }
}

@Riverpod(keepAlive: true)
class PlatformApi extends _$PlatformApi {
  @override
  PlatformApiState build() {
    return PlatformApiState();
  }

  void init() {
    ref.read(tasksProvider);

    /* state.platform.setMethodCallHandler((call) async {
      try {
        final json = (call.arguments as Map).cast<String, dynamic>();
        print(json['role']);
        switch (call.method) {
          case 'commit_surface':
            _commitSurface(
              CommitSurfaceEvent.fromJson(
                json,
              ),
            );
          case 'send_text_input_event':
            _sendTextInputEvent(TextInputEvent.fromJson(json));
          case 'interactive_move':
            _interactiveMove(InteractiveMoveEvent.fromJson(json));
          case 'interactive_resize':
            _interactiveResize(InteractiveResizeEvent.fromJson(json));
          case 'set_title':
            _setTitle(SetTitleEvent.fromJson(json));
          case 'set_app_id':
            _setAppId(SetAppIdEvent.fromJson(json));
          case 'request_maximize':
            _requestMaximize(RequestMaxmizeEvent.fromJson(json));
          case 'destroy_surface':
            await _destroySurface(DestroySurfaceEvent.fromJson(json));
          default:
            throw PlatformException(
              code: 'unknown_method',
              message: 'Unknown method ${call.method}',
            );
        }
      } catch (e, stackTrace) {
        print(e);
        print(stackTrace);
        rethrow;
      }
    }); */
  }

  Future<void> changeWindowVisibility(int surfaceId, bool visible) {
    /* return state.platform.invokeMethod('change_window_visibility', {
      'surface_id': surfaceId,
      'visible': visible,
    }); */
    return Future(() => null);
  }

  Stream<TextInputEventType> getTextInputEventsForViewId(int surfaceId) {
    return state.textInputEventsStream
        .where((event) => event.surfaceId == surfaceId)
        .map((event) {
      switch (event.runtimeType) {
        case EnableTextInputEvent:
          return TextInputEnable();
        case DisableTextInputEvent:
          return TextInputDisable();
        case CommitTextInputEvent:
          return TextInputCommit();
        default:
          throw ArgumentError.value(
            event,
            "Must be 'enable', 'disable', or 'commit'",
            "event['type']",
          );
      }
    });
  }

  /// The display will not generate frame events anymore if it's disabled, meaning that rendering is stopped.
  Future<void> enableDisplay(bool enable) async {
    return state.platform.invokeMethod('enable_display', {
      'enable': enable,
    });
  }

  /* */

  void _sendTextInputEvent(TextInputEvent event) {
    state.textInputEventsSink.add(event);
  }

  /* void _interactiveMove(InteractiveMoveEvent event) {
    ref
        .read(xdgToplevelStatesProvider(event.surfaceId).notifier)
        .requestInteractiveMove();
  }

  void _interactiveResize(InteractiveResizeEvent event) {
    final resizeEdge = ResizeEdge.fromInt(event.edge);
    ref
        .read(xdgToplevelStatesProvider(event.surfaceId).notifier)
        .requestInteractiveResize(resizeEdge);
  } */

  void _setTitle(SetTitleEvent event) {
    ref
        .read(xdgToplevelStatesProvider(event.surfaceId).notifier)
        .setTitle(event.title);
  }

  void _setAppId(SetAppIdEvent event) {
    ref
        .read(xdgToplevelStatesProvider(event.surfaceId).notifier)
        .setTitle(event.appId);
  }

  void _requestMaximize(RequestMaxmizeEvent event) {
    // Do not couple windowStateProvider here.
    ref
        .read(xdgToplevelStatesProvider(event.surfaceId).notifier)
        .requestMaximize(event.maximize);
  }

  /* Future<void> _destroySurface(DestroySurfaceEvent event) async {
    ref.read(surfaceStatesProvider(event.surfaceId).notifier).unmap();
    // TODO: Find a better way. Maybe store subscriptions in a list.
    // 3 sec is more than enough for any close animations.
    await Future.delayed(const Duration(seconds: 3));
    ref.read(surfaceStatesProvider(event.surfaceId).notifier).dispose();
    ref
        .read(surfaceIdsProvider.notifier)
        .update((state) => state.remove(event.surfaceId));
  } */
}

class PlatformApiState {
  PlatformApiState() {
    textInputEventsStream = _textInputEventsStreamController.stream;
    textInputEventsSink = _textInputEventsStreamController.sink;
    windowMappedStream = _windowMappedController.stream;
    windowMappedSink = _windowMappedController.sink;
    windowUnmappedStream = _windowUnmappedController.stream;
    windowUnmappedSink = _windowUnmappedController.sink;
  }
  final _textInputEventsStreamController =
      StreamController<TextInputEvent>.broadcast();
  late final Stream<TextInputEvent> textInputEventsStream;
  late final Sink<TextInputEvent> textInputEventsSink;

  MethodChannel platform = const MethodChannel('platform');

  final _windowMappedController = StreamController<int>.broadcast();
  late final Stream<int> windowMappedStream;
  late final Sink<int> windowMappedSink;

  final _windowUnmappedController = StreamController<int>.broadcast();
  late final Stream<int> windowUnmappedStream;
  late final Sink<int> windowUnmappedSink;
}

abstract class TextInputEventType {}

class TextInputEnable extends TextInputEventType {}

class TextInputDisable extends TextInputEventType {}

class TextInputCommit extends TextInputEventType {}

class AuthenticationResponse {
  AuthenticationResponse(this.success, this.message);

  bool success;
  String message;
}

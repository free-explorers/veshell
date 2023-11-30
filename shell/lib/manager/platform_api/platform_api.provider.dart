import 'dart:async';
import 'dart:ffi' show Finalizable;

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/platform_api/platform_event.model.serializable.dart';
import 'package:shell/shared/tasks/tasks.provider.dart';
import 'package:shell/shared/wayland/subsurface/subsurface.provider.dart';
import 'package:shell/shared/wayland/surface/surface.provider.dart';
import 'package:shell/shared/wayland/surface_ids.provider.dart';
import 'package:shell/shared/wayland/xdg_popup/xdg_popup.provider.dart';
import 'package:shell/shared/wayland/xdg_surface/xdg_surface.provider.dart';
import 'package:shell/shared/wayland/xdg_toplevel/xdg_toplevel.model.dart';
import 'package:shell/shared/wayland/xdg_toplevel/xdg_toplevel.provider.dart';

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
  late final textureFinalizer = Finalizer((int textureId) async {
    // It's possible for a render pass to be late and to use a texture id, even if the object
    // is no longer in memory. Give a generous interval of time for any renders using this texture
    // to finalize.
    await Future.delayed(const Duration(seconds: 1));
    await unregisterViewTexture(textureId);
  });

  @override
  PlatformApiState build() {
    return PlatformApiState();
  }

  void init() {
    ref.read(tasksProvider);

    state.platform.setMethodCallHandler((call) async {
      try {
        final json = (call.arguments as Map).cast<String, dynamic>();
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
    });
  }

  Future<void> startupComplete() {
    return state.platform.invokeMethod('startup_complete');
  }

  Future<void> pointerHoversView(int surfaceId, Offset position) {
    return state.platform.invokeMethod('pointer_hover', {
      'surface_id': surfaceId,
      'x': position.dx,
      'y': position.dy,
    });
  }

  Future<void> sendMouseButtonEventToView(int button, bool isPressed) {
    // One might find surprising that the view id is not sent to the platform. This is because the view id is only sent
    // when the pointer moves, and when a button event happens, the platform already knows which view it hovers.
    return state.platform.invokeMethod('mouse_button_event', {
      'button': button,
      'is_pressed': isPressed,
    });
  }

  Future<void> pointerExitsView() {
    return state.platform.invokeMethod('pointer_exit');
  }

  Future<void> activateWindow(int surfaceId, bool activate) {
    return state.platform
        .invokeMethod('activate_window', [surfaceId, activate]);
  }

  Future<void> changeWindowVisibility(int surfaceId, bool visible) {
    return state.platform.invokeMethod('change_window_visibility', {
      'surface_id': surfaceId,
      'visible': visible,
    });
  }

  Future<void> unregisterViewTexture(int textureId) {
    return state.platform.invokeMethod('unregister_view_texture', textureId);
  }

  Future<void> touchDown(int surfaceId, int touchId, Offset position) {
    return state.platform.invokeMethod('touch_down', {
      'surface_id': surfaceId,
      'touch_id': touchId,
      'x': position.dx,
      'y': position.dy,
    });
  }

  Future<void> touchMotion(int touchId, Offset position) {
    return state.platform.invokeMethod('touch_motion', {
      'touch_id': touchId,
      'x': position.dx,
      'y': position.dy,
    });
  }

  Future<void> touchUp(int touchId) {
    return state.platform.invokeMethod('touch_up', {
      'touch_id': touchId,
    });
  }

  Future<void> touchCancel(int touchId) {
    return state.platform.invokeMethod('touch_cancel', {
      'touch_id': touchId,
    });
  }

  Future<void> insertText(int surfaceId, String text) {
    return state.platform.invokeMethod('insert_text', {
      'surface_id': surfaceId,
      'text': text,
    });
  }

  Future<void> emulateKeyCode(int surfaceId, int keyCode) {
    return state.platform.invokeMethod('emulate_keycode', {
      'surface_id': surfaceId,
      'keycode': keyCode,
    });
  }

  Future<void> openWindowsMaximized(bool value) {
    return state.platform.invokeMethod('open_windows_maximized', value);
  }

  Future<void> maximizedWindowSize(int width, int height) {
    return state.platform.invokeMethod('maximized_window_size', {
      'width': width,
      'height': height,
    });
  }

  Future<void> maximizeWindow(int surfaceId, bool value) {
    return state.platform.invokeMethod('maximize_window', {
      'surface_id': surfaceId,
      'value': value,
    });
  }

  Future<void> resizeWindow(int surfaceId, int width, int height) {
    return state.platform.invokeMethod('resize_window', {
      'surface_id': surfaceId,
      'width': width,
      'height': height,
    });
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

  Future<void> closeView(int surfaceId) {
    return state.platform.invokeMethod('close_window', {
      'surface_id': surfaceId,
    });
  }

  Future<AuthenticationResponse> unlockSession(String password) async {
    final response = await state.platform.invokeMapMethod('unlock_session', {
      'password': password,
    });
    if (response == null) {
      return AuthenticationResponse(false, '');
    }
    return AuthenticationResponse(
      response['success'] as bool,
      response['message'] as String,
    );
  }

  /// The display will not generate frame events anymore if it's disabled, meaning that rendering is stopped.
  Future<void> enableDisplay(bool enable) async {
    return state.platform.invokeMethod('enable_display', {
      'enable': enable,
    });
  }

  void _commitSurface(CommitSurfaceEvent event) {
    ref
        .read(surfaceIdsProvider.notifier)
        .update((state) => state.add(event.surfaceId));

    // TODO: Don't remove the late keyword even if it still compiles !
    // If you remove it, it will run correctly in debug mode but not in release mode.
    // I should make a minimum reproducible example and file a bug.
    late TextureId textureId;

    final currentTextureId =
        ref.read(surfaceStatesProvider(event.surfaceId)).textureId;
    if (event.surface.textureId == currentTextureId.value) {
      textureId = currentTextureId;
    } else {
      textureId = TextureId(event.surface.textureId);
      textureFinalizer.attach(textureId, textureId.value, detach: textureId);
    }

    final inputRegionRect = Rect.fromLTRB(
      event.surface.inputRegion.x1.toDouble(),
      event.surface.inputRegion.y1.toDouble(),
      event.surface.inputRegion.x2.toDouble(),
      event.surface.inputRegion.y2.toDouble(),
    );

    for (final id in event.surface.subsurfacesBelow) {
      ref
          .read(subsurfaceStatesProvider(id).notifier)
          .set_parent(event.surfaceId);
    }

    for (final id in event.surface.subsurfacesAbove) {
      ref
          .read(subsurfaceStatesProvider(id).notifier)
          .set_parent(event.surfaceId);
    }

    ref.read(surfaceStatesProvider(event.surfaceId).notifier).commit(
          role: event.surface.role,
          textureId: textureId,
          surfacePosition:
              Offset(event.surface.x.toDouble(), event.surface.y.toDouble()),
          surfaceSize: Size(
            event.surface.width.toDouble(),
            event.surface.height.toDouble(),
          ),
          scale: event.surface.scale.toDouble(),
          subsurfacesBelow: event.surface.subsurfacesBelow,
          subsurfacesAbove: event.surface.subsurfacesAbove,
          inputRegion: inputRegionRect,
        );

    if (event.xdgSurface != null) {
      final xdgSurface = event.xdgSurface!;
      ref.read(xdgSurfaceStatesProvider(event.surfaceId).notifier).commit(
            role: xdgSurface.role,
            visibleBounds: Rect.fromLTWH(
              xdgSurface.x.toDouble(),
              xdgSurface.y.toDouble(),
              xdgSurface.width.toDouble(),
              xdgSurface.height.toDouble(),
            ),
          );

      if (event.xdgPopup != null) {
        final xdgPopup = event.xdgPopup!;

        // TODO: What to do with the xdgPopup width & height?

        ref.read(xdgPopupStatesProvider(event.surfaceId).notifier).commit(
              parentViewId: xdgPopup.parentId,
              position: Offset(xdgPopup.x.toDouble(), xdgPopup.y.toDouble()),
            );
      }
    }

    if (event.subsurface != null) {
      final subsurface = event.subsurface!;
      final position = Offset(subsurface.x.toDouble(), subsurface.y.toDouble());
      ref.read(subsurfaceStatesProvider(event.surfaceId).notifier).commit(
            position: position,
          );
    }

    if (event.toplevelDecoration != null) {
      ref
          .read(xdgToplevelStatesProvider(event.surfaceId).notifier)
          .setDecoration(event.toplevelDecoration!);
    }

    if (event.toplevelTitle != null) {
      ref
          .read(xdgToplevelStatesProvider(event.surfaceId).notifier)
          .setTitle(event.toplevelTitle!);
    }

    if (event.toplevelAppId != null) {
      ref
          .read(xdgToplevelStatesProvider(event.surfaceId).notifier)
          .setAppId(event.toplevelAppId!);
    }
  }

  void _sendTextInputEvent(TextInputEvent event) {
    state.textInputEventsSink.add(event);
  }

  void _interactiveMove(InteractiveMoveEvent event) {
    ref
        .read(xdgToplevelStatesProvider(event.surfaceId).notifier)
        .requestInteractiveMove();
  }

  void _interactiveResize(InteractiveResizeEvent event) {
    final resizeEdge = ResizeEdge.fromInt(event.edge);
    ref
        .read(xdgToplevelStatesProvider(event.surfaceId).notifier)
        .requestInteractiveResize(resizeEdge);
  }

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

  Future<void> _destroySurface(DestroySurfaceEvent event) async {
    ref.read(surfaceStatesProvider(event.surfaceId).notifier).unmap();
    // TODO: Find a better way. Maybe store subscriptions in a list.
    // 3 sec is more than enough for any close animations.
    await Future.delayed(const Duration(seconds: 3));
    ref.read(surfaceStatesProvider(event.surfaceId).notifier).dispose();
    ref
        .read(surfaceIdsProvider.notifier)
        .update((state) => state.remove(event.surfaceId));
  }

  Future<void> hideKeyboard(int surfaceId) {
    return state.platform.invokeMethod('hide_keyboard', {
      'surface_id': surfaceId,
    });
  }
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

class TextureId implements Finalizable {
  const TextureId(this.value);
  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextureId &&
          runtimeType == other.runtimeType &&
          value == other.value);

  @override
  int get hashCode => value.hashCode;
}

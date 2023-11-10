import 'dart:async';
import 'dart:ffi' show Finalizable;

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/common/state/subsurface_state.dart';
import 'package:zenith/ui/common/state/surface_ids.dart';
import 'package:zenith/ui/common/state/surface_state.dart';
import 'package:zenith/ui/common/state/tasks_provider.dart';
import 'package:zenith/ui/common/state/xdg_popup_state.dart';
import 'package:zenith/ui/common/state/xdg_surface_state.dart';
import 'package:zenith/ui/common/state/xdg_toplevel_state.dart';

part 'generated/platform_api.g.dart';

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
Stream<dynamic> _textInputEventStreamById(_TextInputEventStreamByIdRef ref, int viewId) {
  return ref.watch(platformApiProvider).textInputEventsStream.where((event) => event["view_id"] == viewId);
}

@Riverpod(keepAlive: true)
Future<TextInputEventType> textInputEventStream(TextInputEventStreamRef ref, int viewId) async {
  dynamic event = await ref.watch(_textInputEventStreamByIdProvider(viewId).future);
  switch (event["type"]) {
    case "enable":
      return TextInputEnable();
    case "disable":
      return TextInputDisable();
    case "commit":
      return TextInputCommit();
    default:
      throw ArgumentError.value(event["type"], "Must be 'enable', 'disable', or 'commit'", "event['type']");
  }
}

@Riverpod(keepAlive: true)
class PlatformApi extends _$PlatformApi {
  late final textureFinalizer = Finalizer((int textureId) async {
    // It's possible for a render pass to be late and to use a texture id, even if the object
    // is no longer in memory. Give a generous interval of time for any renders using this texture
    // to finalize.
    await Future.delayed(const Duration(seconds: 1));
    unregisterViewTexture(textureId);
  });

  @override
  PlatformApiState build() {
    return PlatformApiState();
  }

  void init() {
    ref.read(tasksProvider);

    state.platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case "commit_surface":
          _commitSurface(call.arguments);
          break;
        case "send_text_input_event":
          _sendTextInputEvent(call.arguments);
          break;
        case "interactive_move":
          _interactiveMove(call.arguments);
          break;
        case "interactive_resize":
          _interactiveResize(call.arguments);
          break;
        case "set_title":
          _setTitle(call.arguments);
          break;
        case "set_app_id":
          _setAppId(call.arguments);
          break;
        case "request_maximize":
          _requestMaximize(call.arguments);
          break;
        case "destroy_surface":
          _destroySurface(call.arguments);
          break;
        default:
          throw PlatformException(
            code: "unknown_method",
            message: "Unknown method ${call.method}",
          );
      }
    });
  }

  Future<void> startupComplete() {
    return state.platform.invokeMethod("startup_complete");
  }

  Future<void> pointerHoversView(int viewId, Offset position) {
    return state.platform.invokeMethod("pointer_hover", {
      "view_id": viewId,
      "x": position.dx,
      "y": position.dy,
    });
  }

  Future<void> sendMouseButtonEventToView(int button, bool isPressed) {
    // One might find surprising that the view id is not sent to the platform. This is because the view id is only sent
    // when the pointer moves, and when a button event happens, the platform already knows which view it hovers.
    return state.platform.invokeMethod("mouse_button_event", {
      "button": button,
      "is_pressed": isPressed,
    });
  }

  Future<void> pointerExitsView() {
    return state.platform.invokeMethod("pointer_exit");
  }

  Future<void> activateWindow(int viewId, bool activate) {
    return state.platform.invokeMethod('activate_window', [viewId, activate]);
  }

  Future<void> changeWindowVisibility(int viewId, bool visible) {
    return state.platform.invokeMethod('change_window_visibility', {
      "view_id": viewId,
      "visible": visible,
    });
  }

  Future<void> unregisterViewTexture(int textureId) {
    return state.platform.invokeMethod('unregister_view_texture', textureId);
  }

  Future<void> touchDown(int viewId, int touchId, Offset position) {
    return state.platform.invokeMethod('touch_down', {
      "view_id": viewId,
      "touch_id": touchId,
      "x": position.dx,
      "y": position.dy,
    });
  }

  Future<void> touchMotion(int touchId, Offset position) {
    return state.platform.invokeMethod('touch_motion', {
      "touch_id": touchId,
      "x": position.dx,
      "y": position.dy,
    });
  }

  Future<void> touchUp(int touchId) {
    return state.platform.invokeMethod('touch_up', {
      "touch_id": touchId,
    });
  }

  Future<void> touchCancel(int touchId) {
    return state.platform.invokeMethod('touch_cancel', {
      "touch_id": touchId,
    });
  }

  Future<void> insertText(int viewId, String text) {
    return state.platform.invokeMethod('insert_text', {
      "view_id": viewId,
      "text": text,
    });
  }

  Future<void> emulateKeyCode(int viewId, int keyCode) {
    return state.platform.invokeMethod('emulate_keycode', {
      "view_id": viewId,
      "keycode": keyCode,
    });
  }

  Future<void> openWindowsMaximized(bool value) {
    return state.platform.invokeMethod("open_windows_maximized", value);
  }

  Future<void> maximizedWindowSize(int width, int height) {
    return state.platform.invokeMethod("maximized_window_size", {
      "width": width,
      "height": height,
    });
  }

  Future<void> maximizeWindow(int viewId, bool value) {
    return state.platform.invokeMethod("maximize_window", {
      "view_id": viewId,
      "value": value,
    });
  }

  Future<void> resizeWindow(int viewId, int width, int height) {
    return state.platform.invokeMethod("resize_window", {
      "view_id": viewId,
      "width": width,
      "height": height,
    });
  }

  Stream<TextInputEventType> getTextInputEventsForViewId(int viewId) {
    return state.textInputEventsStream.where((event) => event["view_id"] == viewId).map((event) {
      switch (event["type"]) {
        case "enable":
          return TextInputEnable();
        case "disable":
          return TextInputDisable();
        case "commit":
          return TextInputCommit();
        default:
          throw ArgumentError.value(event["type"], "Must be 'enable', 'disable', or 'commit'", "event['type']");
      }
    });
  }

  Future<void> closeView(int viewId) {
    return state.platform.invokeMethod("close_window", {
      "view_id": viewId,
    });
  }

  Future<AuthenticationResponse> unlockSession(String password) async {
    Map<String, dynamic>? response = await state.platform.invokeMapMethod("unlock_session", {
      "password": password,
    });
    if (response == null) {
      return AuthenticationResponse(false, "");
    }
    return AuthenticationResponse(response["success"] as bool, response["message"] as String);
  }

  /// The display will not generate frame events anymore if it's disabled, meaning that rendering is stopped.
  Future<void> enableDisplay(bool enable) async {
    return state.platform.invokeMethod("enable_display", {
      "enable": enable,
    });
  }

  void _commitSurface(dynamic event) {
    int viewId = event["view_id"];
    ref.read(surfaceIdsProvider.notifier).update((state) => state.add(viewId));

    dynamic surface = event["surface"];
    int role = surface["role"];

    int textureIdInt = surface["textureId"];
    // TODO: Don't remove the late keyword even if it still compiles !
    // If you remove it, it will run correctly in debug mode but not in release mode.
    // I should make a minimum reproducible example and file a bug.
    late TextureId textureId;

    TextureId currentTextureId = ref.read(surfaceStatesProvider(viewId)).textureId;
    if (textureIdInt == currentTextureId.value) {
      textureId = currentTextureId;
    } else {
      textureId = TextureId(textureIdInt);
      textureFinalizer.attach(textureId, textureId.value, detach: textureId);
    }

    int x = surface["x"];
    int y = surface["y"];
    int width = surface["width"];
    int height = surface["height"];
    int scale = surface["scale"];

    dynamic inputRegion = surface["input_region"];
    int left = inputRegion["x1"];
    int top = inputRegion["y1"];
    int right = inputRegion["x2"];
    int bottom = inputRegion["y2"];
    var inputRegionRect = Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    );

    List<dynamic> subsurfaceBelow = surface["subsurfaces_below"];
    List<dynamic> subsurfaceAbove = surface["subsurfaces_above"];

    List<int> subsurfaceIdsBelow = subsurfaceBelow.cast<int>();
    List<int> subsurfaceIdsAbove = subsurfaceAbove.cast<int>();

    for (int id in subsurfaceIdsBelow) {
      ref.read(subsurfaceStatesProvider(id).notifier).set_parent(viewId);
    }

    for (int id in subsurfaceIdsAbove) {
      ref.read(subsurfaceStatesProvider(id).notifier).set_parent(viewId);
    }

    ref.read(surfaceStatesProvider(viewId).notifier).commit(
          role: SurfaceRole.values[role],
          textureId: textureId,
          surfacePosition: Offset(x.toDouble(), y.toDouble()),
          surfaceSize: Size(width.toDouble(), height.toDouble()),
          scale: scale.toDouble(),
          subsurfacesBelow: subsurfaceIdsBelow,
          subsurfacesAbove: subsurfaceIdsAbove,
          inputRegion: inputRegionRect,
        );

    bool hasXdgSurface = event["has_xdg_surface"];
    if (hasXdgSurface) {
      dynamic xdgSurface = event["xdg_surface"];
      int role = xdgSurface["role"];
      int x = xdgSurface["x"];
      int y = xdgSurface["y"];
      int width = xdgSurface["width"];
      int height = xdgSurface["height"];

      ref.read(xdgSurfaceStatesProvider(viewId).notifier).commit(
            role: XdgSurfaceRole.values[role],
            visibleBounds: Rect.fromLTWH(
              x.toDouble(),
              y.toDouble(),
              width.toDouble(),
              height.toDouble(),
            ),
          );

      bool hasXdgPopup = event["has_xdg_popup"];
      if (hasXdgPopup) {
        dynamic xdgPopup = event["xdg_popup"];
        int parentId = xdgPopup["parent_id"];
        int x = xdgPopup["x"];
        int y = xdgPopup["y"];
        // TODO: What to do with these?
        int width = xdgPopup["width"];
        int height = xdgPopup["height"];

        ref.read(xdgPopupStatesProvider(viewId).notifier).commit(
              parentViewId: parentId,
              position: Offset(x.toDouble(), y.toDouble()),
            );
      }
    }

    bool hasSubsurface = event["has_subsurface"];
    if (hasSubsurface) {
      dynamic subsurface = event["subsurface"];
      int x = subsurface["x"];
      int y = subsurface["y"];
      var position = Offset(x.toDouble(), y.toDouble());
      ref.read(subsurfaceStatesProvider(viewId).notifier).commit(
            position: position,
          );
    }

    bool hasToplevelDecoration = event["has_toplevel_decoration"];
    if (hasToplevelDecoration) {
      int toplevelDecorationInt = event["toplevel_decoration"];
      var decoration = ToplevelDecoration.fromInt(toplevelDecorationInt);
      ref.read(xdgToplevelStatesProvider(viewId).notifier).setDecoration(decoration);
    }

    bool hasToplevelTitle = event["has_toplevel_title"];
    if (hasToplevelTitle) {
      String title = event["toplevel_title"];
      ref.read(xdgToplevelStatesProvider(viewId).notifier).setTitle(title);
    }

    bool hasToplevelAppId = event["has_toplevel_app_id"];
    if (hasToplevelAppId) {
      String appId = event["toplevel_app_id"];
      ref.read(xdgToplevelStatesProvider(viewId).notifier).setAppId(appId);
    }
  }

  void _sendTextInputEvent(dynamic event) {
    state.textInputEventsSink.add(event);
  }

  void _interactiveMove(dynamic event) {
    int viewId = event["view_id"];
    ref.read(xdgToplevelStatesProvider(viewId).notifier).requestInteractiveMove();
  }

  void _interactiveResize(dynamic event) {
    int viewId = event["view_id"];
    int edge = event["edge"];
    ResizeEdge resizeEdge = ResizeEdge.fromInt(edge);
    ref.read(xdgToplevelStatesProvider(viewId).notifier).requestInteractiveResize(resizeEdge);
  }

  void _setTitle(dynamic event) {
    int viewId = event["view_id"];
    String title = event["title"];
    ref.read(xdgToplevelStatesProvider(viewId).notifier).setTitle(title);
  }

  void _setAppId(dynamic event) {
    int viewId = event["view_id"];
    String appId = event["app_id"];
    ref.read(xdgToplevelStatesProvider(viewId).notifier).setTitle(appId);
  }

  void _requestMaximize(dynamic event) {
    int viewId = event["view_id"];
    bool maximize = event["maximize"];
    // Do not couple windowStateProvider here.
    ref.read(xdgToplevelStatesProvider(viewId).notifier).requestMaximize(maximize);
  }

  void _destroySurface(dynamic event) async {
    int viewId = event["view_id"];
    ref.read(surfaceStatesProvider(viewId).notifier).unmap();
    // TODO: Find a better way. Maybe store subscriptions in a list.
    // 3 sec is more than enough for any close animations.
    await Future.delayed(const Duration(seconds: 3));
    ref.read(surfaceStatesProvider(viewId).notifier).dispose();
    ref.read(surfaceIdsProvider.notifier).update((state) => state.remove(viewId));
  }

  Future<void> hideKeyboard(int viewId) {
    return state.platform.invokeMethod('hide_keyboard', {
      "view_id": viewId,
    });
  }
}

class PlatformApiState {
  final _textInputEventsStreamController = StreamController<dynamic>.broadcast();
  late final Stream<dynamic> textInputEventsStream;
  late final Sink<dynamic> textInputEventsSink;

  MethodChannel platform = const MethodChannel('platform');

  final _windowMappedController = StreamController<int>.broadcast();
  late final Stream<int> windowMappedStream;
  late final Sink<int> windowMappedSink;

  final _windowUnmappedController = StreamController<int>.broadcast();
  late final Stream<int> windowUnmappedStream;
  late final Sink<int> windowUnmappedSink;

  PlatformApiState() {
    textInputEventsStream = _textInputEventsStreamController.stream;
    textInputEventsSink = _textInputEventsStreamController.sink;
    windowMappedStream = _windowMappedController.stream;
    windowMappedSink = _windowMappedController.sink;
    windowUnmappedStream = _windowUnmappedController.stream;
    windowUnmappedSink = _windowUnmappedController.sink;
  }
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
  final int value;

  TextureId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TextureId && runtimeType == other.runtimeType && value == other.value);

  @override
  int get hashCode => value.hashCode;
}

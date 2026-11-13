import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/dev_tools/probe/probe_clock.dart';
import 'package:shell/monitor/provider/monitor_by_view_id.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/shared/util/paint_placement.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

export 'package:shell/shared/util/paint_placement.dart'
    show ProbePaintsEveryChild;

/// The `ext.veshell.*` service extensions `veshell-probe` drives the shell
/// with (see `docs/specifications/veshell_probe.md`): views, `find`, `act`,
/// `capture` and `state`.
///
/// Debug builds only: in any other build this registers nothing.
void registerProbeExtensions(ProviderContainer container) {
  if (!kDebugMode) {
    return;
  }
  final probe = VeshellProbe(container);
  _register('views', (_) async => probe.views());
  _register('info', (_) async => probe.info());
  _register('settled', (_) async => probe.settled());
  _register(
    'find',
    (params) async => probe.find(ProbeQuery.fromParams(params)),
  );
  _register('act', probe.act);
  _register('capture', probe.capture);
  _register('state', (params) async => probe.state(params['store'] ?? 'all'));
  _register('clock', (params) async {
    final clock = ProbeClock.instance;
    return switch (params['action']) {
      'freeze' => clock.freeze(),
      'step' => clock.step(
        Duration(
          microseconds: ((double.tryParse(params['ms'] ?? '') ?? 0) * 1000)
              .round(),
        ),
      ),
      'resume' => clock.resume(),
      'status' || null => clock.status(),
      final other => throw ProbeException(
        'Unknown clock action "$other": freeze, step, resume or status',
      ),
    };
  });
}

void _register(
  String name,
  Future<Object?> Function(Map<String, String> params) handler,
) {
  try {
    developer.registerExtension('ext.veshell.$name', (method, params) async {
      try {
        // A service extension answers with a JSON object.
        final result = await handler(params);
        return developer.ServiceExtensionResponse.result(
          jsonEncode(result is Map ? result : {'value': result}),
        );
      } on ProbeException catch (error) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          error.message,
        );
      } on Object catch (error, stackTrace) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          '$error\n$stackTrace',
        );
      }
    });
    // A hot restart keeps the isolate's extensions: registering again throws.
    // ignore: avoid_catching_errors
  } on ArgumentError {
    // Already registered.
  }
}

/// A request the probe cannot serve, reported to the caller as is.
class ProbeException implements Exception {
  ProbeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Which widgets a probe call is about: by widget type (`runtimeType`), by
/// key (a `ValueKey`'s value, or the key's description) or by the text it
/// shows; all the given criteria must match.
class ProbeQuery {
  const ProbeQuery({this.type, this.key, this.text, this.limit = 20});

  factory ProbeQuery.fromParams(Map<String, String> params) {
    final query = ProbeQuery(
      type: params['type'],
      key: params['key'],
      text: params['text'],
      limit: int.tryParse(params['limit'] ?? '') ?? 20,
    );
    if (query.type == null && query.key == null && query.text == null) {
      throw ProbeException('Give a type, a key or a text to find');
    }
    return query;
  }

  final String? type;
  final String? key;
  final String? text;
  final int limit;

  bool matches(Widget widget) {
    if (type != null && _typeName(widget) != type) {
      return false;
    }
    if (key != null && !_keyMatches(widget.key, key!)) {
      return false;
    }
    if (text != null && !(_textOf(widget)?.contains(text!) ?? false)) {
      return false;
    }
    return true;
  }
}

String _typeName(Object object) {
  final name = object.runtimeType.toString();
  final generic = name.indexOf('<');
  return generic < 0 ? name : name.substring(0, generic);
}

bool _keyMatches(Key? key, String wanted) => switch (key) {
  null => false,
  ValueKey(:final value) => '$value' == wanted || '$key' == wanted,
  _ => '$key' == wanted,
};

String? _keyLabel(Key? key) => switch (key) {
  null => null,
  ValueKey(:final value) => '$value',
  _ => '$key',
};

String? _textOf(Widget widget) => switch (widget) {
  Text(:final data?) => data,
  Text(:final textSpan?) => textSpan.toPlainText(),
  EditableText(:final controller) => controller.text,
  _ => null,
};

/// The shell side of `veshell-probe`.
class VeshellProbe {
  VeshellProbe(this.container);

  final ProviderContainer container;

  /// The shell's views (one per monitor), with their logical size and the
  /// monitor (the compositor's output) each shows.
  List<Map<String, Object?>> views() => [
    for (final view in RendererBinding.instance.renderViews)
      {
        'viewId': view.flutterView.viewId,
        'monitor': container.read(
          monitorByViewIdProvider(view.flutterView.viewId),
        ),
        'width': view.size.width,
        'height': view.size.height,
        'devicePixelRatio': view.flutterView.devicePixelRatio,
      },
  ];

  /// What the probe needs to reach the compositor side: its control socket
  /// (`VESHELL_PROBE_SOCKET`, exported by a debug embedder).
  Map<String, Object?> info() => {
    'probeSocket': Platform.environment['VESHELL_PROBE_SOCKET'],
    'pid': pid,
  };

  /// Whether the shell is idle: no frame pending and no animation running
  /// (as `pumpAndSettle` waits for in tests). A screenshot compared with a
  /// reference waits for it, so it does not catch the shell mid-change.
  Map<String, Object?> settled() {
    final scheduler = SchedulerBinding.instance;
    return {
      'settled':
          !scheduler.hasScheduledFrame &&
          scheduler.transientCallbackCount == 0 &&
          scheduler.schedulerPhase == SchedulerPhase.idle,
      'transientCallbacks': scheduler.transientCallbackCount,
    };
  }

  /// The widgets matching [query], each with where it is on screen.
  Map<String, Object?> find(ProbeQuery query) {
    final matches = <Map<String, Object?>>[];
    var count = 0;
    void visit(Element element) {
      if (query.matches(element.widget)) {
        count++;
        if (matches.length < query.limit) {
          matches.add(_describe(element));
        }
      }
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    return {'count': count, 'matches': matches};
  }

  Map<String, Object?> _describe(Element element) {
    final widget = element.widget;
    final renderObject = element.renderObject;
    final description = <String, Object?>{
      'type': _typeName(widget),
      'key': _keyLabel(widget.key),
      'text': _textOf(widget),
      'viewId': View.maybeOf(element)?.viewId,
    };
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return {...description, 'laidOut': false};
    }
    final placement = probePlacement(renderObject);
    if (!_isFinite(placement.rect)) {
      // A transform that collapses the box (a scale through zero mid
      // animation) leaves it nowhere: it is not on screen.
      return {
        ...description,
        'laidOut': true,
        'degenerate': true,
        'rect': null,
        'visibleRect': null,
        'opacity': placement.opacity.isFinite ? placement.opacity : 0,
        'painted': placement.painted,
        'visible': false,
      };
    }
    return {
      ...description,
      'laidOut': true,
      'rect': _rectJson(placement.rect),
      'visibleRect':
          placement.visibleRect == null || !_isFinite(placement.visibleRect!)
          ? null
          : _rectJson(placement.visibleRect!),
      'opacity': placement.opacity,
      'painted': placement.painted,
      'visible':
          placement.painted &&
          placement.opacity > 0 &&
          !(placement.visibleRect?.isEmpty ?? true),
    };
  }

  /// Taps, presses a key or types (`action` = `tap`, `key` or `type`).
  Future<Map<String, Object?>> act(Map<String, String> params) async {
    switch (params['action']) {
      case 'tap':
        return await _tap(params);
      case 'key':
        return await _key(params['key'] ?? '');
      case 'type':
        return await _type(
          params['text'] ?? '',
          clear: params['clear'] == 'true',
        );
      case final other:
        throw ProbeException('Unknown action "$other": tap, key or type');
    }
  }

  static int _nextPointer = 1 << 20;

  Future<Map<String, Object?>> _tap(Map<String, String> params) async {
    var viewId = int.tryParse(params['viewId'] ?? '');
    Offset position;
    final x = double.tryParse(params['x'] ?? '');
    final y = double.tryParse(params['y'] ?? '');
    if (x != null && y != null) {
      position = Offset(x, y);
    } else {
      final found = find(ProbeQuery.fromParams(params));
      final index = int.tryParse(params['index'] ?? '') ?? 0;
      final matches = found['matches']! as List<Map<String, Object?>>;
      if (index >= matches.length) {
        throw ProbeException('No match #$index to tap (${found['count']})');
      }
      final match = matches[index];
      final visible = match['visibleRect'] as Map<String, Object?>?;
      if (match['visible'] != true || visible == null) {
        throw ProbeException('The match is not visible: $match');
      }
      position = Rect.fromLTWH(
        visible['left']! as double,
        visible['top']! as double,
        visible['width']! as double,
        visible['height']! as double,
      ).center;
      viewId ??= match['viewId'] as int?;
    }
    viewId ??= RendererBinding.instance.renderViews.first.flutterView.viewId;

    // A touch: unlike a mouse, it needs no hover or device-added events.
    final pointer = _nextPointer++;
    GestureBinding.instance
      ..handlePointerEvent(
        PointerDownEvent(viewId: viewId, pointer: pointer, position: position),
      )
      ..handlePointerEvent(
        PointerUpEvent(viewId: viewId, pointer: pointer, position: position),
      );
    return {
      'tapped': {'viewId': viewId, 'x': position.dx, 'y': position.dy},
    };
  }

  Future<Map<String, Object?>> _key(String chord) async {
    final names = chord.split('+').map((name) => name.trim()).toList();
    if (names.isEmpty || names.last.isEmpty) {
      throw ProbeException('Give a key, such as Enter or Control+Arrow Down');
    }
    final keys = [for (final name in names) _keyNamed(name)];

    // A text field's Enter is its input action (the platform's text input
    // sends it), not a key event.
    final editable = _focusedEditable();
    if (keys.length == 1 &&
        keys.single.$2 == LogicalKeyboardKey.enter &&
        editable != null) {
      editable.performAction(
        editable.widget.textInputAction ?? TextInputAction.done,
      );
      return {'key': chord, 'as': 'textInputAction'};
    }

    var handled = false;
    for (final (physical, logical) in keys) {
      handled |= _sendKey(
        KeyDownEvent(
          physicalKey: physical,
          logicalKey: logical,
          timeStamp: Duration.zero,
        ),
      );
    }
    for (final (physical, logical) in keys.reversed) {
      _sendKey(
        KeyUpEvent(
          physicalKey: physical,
          logicalKey: logical,
          timeStamp: Duration.zero,
        ),
      );
    }
    return {'key': chord, 'handled': handled};
  }

  /// Delivers [event] as the platform would: to the keyboard state, then to
  /// the focus system (shortcuts, `Focus.onKeyEvent`).
  bool _sendKey(KeyEvent event) {
    final byHandlers = HardwareKeyboard.instance.handleKeyEvent(event);
    // Deprecated, but still how `FocusManager` receives real key presses in
    // the pinned Flutter: the shortcuts and `Focus.onKeyEvent` handlers
    // listen there, not on `HardwareKeyboard`.
    final byFocus =
        // ignore: deprecated_member_use, see above.
        ServicesBinding.instance.keyEventManager.keyMessageHandler?.call(
          // ignore: deprecated_member_use, see above.
          KeyMessage([event], null),
        ) ??
        false;
    return byHandlers || byFocus;
  }

  (PhysicalKeyboardKey, LogicalKeyboardKey) _keyNamed(String name) {
    final wanted = name.toLowerCase().replaceAll(' ', '');
    bool same(String? label) =>
        label != null && label.toLowerCase().replaceAll(' ', '') == wanted;
    final aliases = {
      'ctrl': 'controlleft',
      'control': 'controlleft',
      'shift': 'shiftleft',
      'alt': 'altleft',
      'super': 'metaleft',
      'meta': 'metaleft',
      'esc': 'escape',
      'return': 'enter',
      'up': 'arrowup',
      'down': 'arrowdown',
      'left': 'arrowleft',
      'right': 'arrowright',
    };
    final resolved = aliases[wanted] ?? wanted;
    bool sameResolved(String? label) =>
        label != null && label.toLowerCase().replaceAll(' ', '') == resolved;
    final logical = LogicalKeyboardKey.knownLogicalKeys
        .where((key) => sameResolved(key.debugName) || same(key.keyLabel))
        .firstOrNull;
    if (logical == null) {
      throw ProbeException('Unknown key "$name"');
    }
    final physical =
        PhysicalKeyboardKey.knownPhysicalKeys
            .where((key) => key.debugName == logical.debugName)
            .firstOrNull ??
        PhysicalKeyboardKey(logical.keyId);
    return (physical, logical);
  }

  EditableTextState? _focusedEditable() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      return null;
    }
    // The focused node may sit inside the editable text or around it (a
    // text field's own `Focus`).
    final above = context.findAncestorStateOfType<EditableTextState>();
    if (above != null) {
      return above;
    }
    EditableTextState? below;
    void visit(Element element) {
      if (below != null) {
        return;
      }
      if (element is StatefulElement && element.state is EditableTextState) {
        below = element.state as EditableTextState;
        return;
      }
      element.visitChildElements(visit);
    }

    if (context is Element) {
      visit(context);
    }
    return below;
  }

  Future<Map<String, Object?>> _type(String text, {required bool clear}) async {
    final editable = _focusedEditable();
    if (editable == null) {
      throw ProbeException('No text field has the keyboard');
    }
    final value = editable.textEditingValue;
    final next = clear
        ? TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          )
        : value.replaced(
            value.selection.isValid
                ? value.selection
                : TextRange.collapsed(value.text.length),
            text,
          );
    editable.userUpdateTextEditingValue(next, SelectionChangedCause.keyboard);
    return {'text': editable.textEditingValue.text};
  }

  /// A PNG of what a view painted on its last frame (or of a part of it),
  /// with the animation clock time it shows.
  Future<Map<String, Object?>> capture(Map<String, String> params) async {
    final viewId = int.tryParse(params['viewId'] ?? '');
    final views = RendererBinding.instance.renderViews;
    final renderView = viewId == null
        ? views.first
        : views.where((view) => view.flutterView.viewId == viewId).firstOrNull;
    if (renderView == null) {
      throw ProbeException('No view $viewId');
    }
    // A change made just before (an action, an animation tick) is painted
    // on the next frame: capture that one, so the image shows the same
    // moment as the geometry `find` reports.
    // Bounded: frames come from the engine's vsync, which never ticks where
    // nothing pumps them (a widget test), and a capture must not hang.
    if (SchedulerBinding.instance.hasScheduledFrame) {
      await SchedulerBinding.instance.endOfFrame.timeout(
        const Duration(milliseconds: 250),
        onTimeout: () {},
      );
    }
    final pixelRatio = double.tryParse(params['pixelRatio'] ?? '') ?? 1.0;
    final bounds = Offset.zero & renderView.size;
    final region = switch ((
      double.tryParse(params['left'] ?? ''),
      double.tryParse(params['top'] ?? ''),
      double.tryParse(params['width'] ?? ''),
      double.tryParse(params['height'] ?? ''),
    )) {
      (final left?, final top?, final width?, final height?) => Rect.fromLTWH(
        left,
        top,
        width,
        height,
      ).intersect(bounds),
      _ => bounds,
    };
    final image = await probeCaptureView(renderView, region, pixelRatio);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      return {
        'viewId': renderView.flutterView.viewId,
        'rect': _rectJson(region),
        'pixelWidth': image.width,
        'pixelHeight': image.height,
        'frameTimeMicros':
            SchedulerBinding.instance.hasScheduledFrame ||
                SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle
            ? null
            : SchedulerBinding
                  .instance
                  .currentSystemFrameTimeStamp
                  .inMicroseconds,
        'timeDilation': timeDilation,
        'png': base64Encode(png!.buffer.asUint8List()),
      };
    } finally {
      image.dispose();
    }
  }

  /// JSON snapshots of the shell's state: `screens`, `workspaces`,
  /// `windows`, or `all`.
  Map<String, Object?> state(String store) {
    const stores = {'screens', 'workspaces', 'windows'};
    if (store != 'all' && !stores.contains(store)) {
      throw ProbeException('Unknown store "$store": ${stores.join(', ')}, all');
    }
    final screenIds = container.read(screenManagerProvider).screenIds;
    final screens = {
      for (final id in screenIds) id: container.read(screenStateProvider(id)),
    };
    final workspaceIds = [
      for (final screen in screens.values) ...screen.workspaceList,
    ];
    final workspaces = {
      for (final id in workspaceIds)
        id: container.read(workspaceStateProvider(id)),
    };
    final windowIds = [
      for (final workspace in workspaces.values)
        ...workspace.tileableWindowList,
    ];
    Object? json(Object? value) => jsonDecode(jsonEncode(value));
    final snapshot = <String, Object?>{
      'screens': json({
        for (final entry in screens.entries) entry.key: entry.value.toJson(),
      }),
      'workspaces': json({
        for (final entry in workspaces.entries) entry.key: entry.value.toJson(),
      }),
      'windows': json({
        for (final id in windowIds)
          id.uuid: container.read(persistentWindowStateProvider(id)).toJson(),
      }),
    };
    return store == 'all' ? snapshot : {store: snapshot[store]};
  }
}

bool _isFinite(Rect rect) =>
    rect.left.isFinite &&
    rect.top.isFinite &&
    rect.width.isFinite &&
    rect.height.isFinite;

Map<String, Object?> _rectJson(Rect rect) => {
  'left': rect.left,
  'top': rect.top,
  'width': rect.width,
  'height': rect.height,
};

/// Where [box] is on its view; see [paintPlacement].
@visibleForTesting
({Rect rect, Rect? visibleRect, double opacity, bool painted}) probePlacement(
  RenderBox box,
) => paintPlacement(box);

/// Renders the layer tree [renderView] painted on its last frame, cropped to
/// [region] (logical pixels), at [pixelRatio].
@visibleForTesting
Future<ui.Image> probeCaptureView(
  RenderView renderView,
  Rect region,
  double pixelRatio,
) {
  // The root layer maps logical pixels to the view's physical ones; render
  // its children in logical pixels, at the requested ratio.
  final root = renderView.debugLayer! as OffsetLayer;
  final layer = root.firstChild;
  final scene = ui.SceneBuilder()
    ..pushTransform(Matrix4.diagonal3Values(pixelRatio, pixelRatio, 1).storage)
    ..pushOffset(-region.left, -region.top);
  if (layer != null) {
    root.addChildrenToScene(scene);
  }
  scene
    ..pop()
    ..pop();
  final built = scene.build();
  try {
    return built.toImage(
      (region.width * pixelRatio).ceil(),
      (region.height * pixelRatio).ceil(),
    );
  } finally {
    built.dispose();
  }
}

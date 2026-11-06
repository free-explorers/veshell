import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:veshell_probe/src/compositor.dart';
import 'package:veshell_probe/src/connection.dart';
import 'package:veshell_probe/src/contact_sheet.dart';
import 'package:vm_service/vm_service.dart';

/// The widest image returned inline by the tool server: wider ones are
/// scaled down.
const maxAgentImageWidth = 1568;

/// Where the probe writes its captures: `build/probe/<time>-<label>/` under
/// the repository (ignored by git), or under the working directory outside
/// one.
class ProbeOutput {
  ProbeOutput(this.root);

  final String root;

  static ProbeOutput forRepository(String? repositoryRoot) => ProbeOutput(
    p.join(repositoryRoot ?? Directory.current.path, 'build', 'probe'),
  );

  /// A new directory for one command's files.
  Directory newDirectory(String label) {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}-'
        '${now.millisecond.toString().padLeft(3, '0')}';
    return Directory(p.join(root, '$stamp-$label'))
      ..createSync(recursive: true);
  }
}

/// Which widgets a call is about (see `ext.veshell.find`).
class WidgetQuery {
  const WidgetQuery({this.type, this.key, this.text});

  /// Parses `type=…`, `key=…` or `text=…`, comma separated.
  factory WidgetQuery.parse(String spec) {
    String? type;
    String? key;
    String? text;
    for (final part in _splitCriteria(spec)) {
      final separator = part.indexOf('=');
      if (separator < 0) {
        throw ProbeError('Expected type=…, key=… or text=…, got "$part"');
      }
      final value = part.substring(separator + 1);
      switch (part.substring(0, separator).trim()) {
        case 'type':
          type = value;
        case 'key':
          key = value;
        case 'text':
          text = value;
        case final other:
          throw ProbeError('Unknown criterion "$other": type, key or text');
      }
    }
    return WidgetQuery(type: type, key: key, text: text);
  }

  /// [spec] split on its unescaped commas; `\,` is a comma and `\\` a
  /// backslash inside a value.
  static List<String> _splitCriteria(String spec) {
    final parts = <String>[];
    final current = StringBuffer();
    for (var index = 0; index < spec.length; index++) {
      final char = spec[index];
      if (char == r'\' && index + 1 < spec.length) {
        final next = spec[index + 1];
        if (next == ',' || next == r'\') {
          current.write(next);
          index++;
          continue;
        }
      }
      if (char == ',') {
        parts.add('$current');
        current.clear();
      } else {
        current.write(char);
      }
    }
    parts.add('$current');
    return parts;
  }

  final String? type;
  final String? key;
  final String? text;

  bool get isEmpty => type == null && key == null && text == null;

  Map<String, Object?> toParams() => {'type': type, 'key': key, 'text': text};

  @override
  String toString() => [
    if (type != null) 'type=$type',
    if (key != null) 'key=$key',
    if (text != null) 'text=$text',
  ].join(',');
}

/// A PNG the probe captured, with where it was written.
class Capture {
  Capture(this.info, this.png, this.path);

  final Map<String, Object?> info;
  final Uint8List png;
  final String path;
}

/// The result of `animate`.
class AnimateResult {
  AnimateResult(this.report, this.sheet, this.sheetPath);

  final Map<String, Object?> report;
  final Uint8List sheet;
  final String sheetPath;
}

/// The probe's operations on one instance, for the command line and the tool
/// server alike.
/// The most frames [Probe.animate] captures in one call.
const maxAnimateFrames = 120;

class Probe {
  Probe(this.connection, this.output);

  final ProbeConnection connection;
  final ProbeOutput output;

  Future<List<Object?>> views() async =>
      (await connection.call('views'))! as List<Object?>;

  Future<Map<String, Object?>> find(WidgetQuery query, {int limit = 20}) async {
    if (query.isEmpty) {
      throw ProbeError('Give a type, a key or a text to find');
    }
    return (await connection.call('find', {
          ...query.toParams(),
          'limit': limit,
        }))!
        as Map<String, Object?>;
  }

  CompositorControl? _compositor;
  bool _compositorLooked = false;

  /// The embedder's control socket, when the instance is a debug build that
  /// has it.
  Future<CompositorControl?> compositor() async {
    if (!_compositorLooked) {
      _compositorLooked = true;
      try {
        final info = (await connection.call('info'))! as Map<String, Object?>;
        if (info['probeSocket'] case final String path
            when File(path).existsSync()) {
          _compositor = CompositorControl(path);
        }
      } on ProbeError {
        // An older shell without `ext.veshell.info`.
      }
    }
    return _compositor;
  }

  Future<CompositorControl> _requireCompositor() async =>
      await compositor() ??
      (throw ProbeError(
        'The instance has no compositor control socket (an older or non-debug '
        'embedder): use via=flutter',
      ));

  /// Taps, presses a key chord or types (`params['action']` = `tap`, `key`
  /// or `type`): through the compositor, as a device would ([via] =
  /// `compositor`, the default when the instance can), or straight into
  /// Flutter (`flutter`).
  Future<Map<String, Object?>> act(
    Map<String, Object?> params, {
    String? via,
  }) async {
    final route =
        via ?? (await compositor() != null ? 'compositor' : 'flutter');
    if (route == 'flutter') {
      return (await connection.call('act', params))! as Map<String, Object?>;
    }
    if (route != 'compositor') {
      throw ProbeError('via is compositor or flutter, not "$route"');
    }
    final control = await _requireCompositor();
    switch (params['action']) {
      case 'tap':
        final point = await _compositorPoint(params);
        await control.inject(clickEvents(point.x, point.y));
        return {
          'via': 'compositor',
          'tapped': {'x': point.x, 'y': point.y},
        };
      case 'key':
        await control.inject(chordEvents('${params['key']}'));
        return {'via': 'compositor', 'key': params['key']};
      case 'type':
        if (params['clear'] == true) {
          // Clearing is an edit, not keystrokes: Flutter does it.
          return {
            ...((await connection.call('act', params))!
                as Map<String, Object?>),
            'via': 'flutter',
          };
        }
        await control.inject(typingEvents('${params['text']}'));
        return {'via': 'compositor', 'typed': params['text']};
      case final other:
        throw ProbeError('Unknown action "$other": tap, key or type');
    }
  }

  /// Where a tap lands in compositor coordinates: a given view point, or a
  /// found widget's visible center, offset by its view's output.
  Future<({double x, double y})> _compositorPoint(
    Map<String, Object?> params,
  ) async {
    int? viewId = (params['viewId'] as num?)?.toInt();
    double x;
    double y;
    if (params['x'] case final num px) {
      x = px.toDouble();
      y = (params['y']! as num).toDouble();
    } else {
      final query = WidgetQuery(
        type: params['type'] as String?,
        key: params['key'] as String?,
        text: params['text'] as String?,
      );
      final match = await _match(
        query,
        (params['index'] as num?)?.toInt() ?? 0,
      );
      final visible = match['visibleRect'] as Map?;
      if (match['visible'] != true || visible == null) {
        throw ProbeError('The match for $query is not visible: $match');
      }
      x = (visible['left']! as num) + (visible['width']! as num) / 2;
      y = (visible['top']! as num) + (visible['height']! as num) / 2;
      viewId ??= (match['viewId'] as num?)?.toInt();
    }
    final origin = await _outputOrigin(viewId);
    return (x: origin.x + x, y: origin.y + y);
  }

  /// View [viewId], or the first view when null; a missing view is an
  /// error, never another view.
  Future<Map> _view(int? viewId) async {
    final views = (await this.views()).cast<Map>();
    if (views.isEmpty) {
      throw ProbeError('The instance has no view');
    }
    if (viewId == null) {
      return views.first;
    }
    return views.firstWhere(
      (view) => view['viewId'] == viewId,
      orElse: () => throw ProbeError(
        'No view $viewId (views: ${views.map((v) => v['viewId']).join(', ')})',
      ),
    );
  }

  /// The compositor position of the corner of view [viewId] (the first
  /// view's when null): its output's.
  Future<({double x, double y})> _outputOrigin(int? viewId) async {
    final view = await _view(viewId);
    final outputs = await (await _requireCompositor()).outputs();
    final named = outputs.where((output) => output['name'] == view['monitor']);
    // Without a monitor name, only a single output is unambiguous.
    final output = named.isNotEmpty
        ? named.first
        : view['monitor'] == null && outputs.length == 1
        ? outputs.single
        : throw ProbeError(
            'No output for view ${view['viewId']} (monitor '
            '${view['monitor']}; outputs: '
            '${outputs.map((o) => o['name']).join(', ')})',
          );
    final geometry = output['geometry']! as Map;
    return (
      x: (geometry['left']! as num).toDouble(),
      y: (geometry['top']! as num).toDouble(),
    );
  }

  /// The composited output of view [viewId] (application windows included),
  /// cropped to [target]'s region when given.
  Future<Capture> compositorScreenshot({
    int? viewId,
    WidgetQuery? target,
    int index = 0,
    double? pixelRatio,
    int? maxWidth,
    Directory? into,
    String name = 'screenshot',
  }) async {
    final control = await _requireCompositor();
    // A target decides the view: the output captured is the one its match
    // is on, so that the crop below applies to the right picture.
    Map? rect;
    if (target != null && !target.isEmpty) {
      final match = await _match(target, index);
      rect = match['rect']! as Map;
      viewId = (match['viewId'] as num?)?.toInt() ?? viewId;
    }
    final view = await _view(viewId);
    final directory = into ?? output.newDirectory(name);
    final path = p.join(directory.path, '$name.png');
    final info = await control.captureOutput(
      path,
      output: view['monitor'] as String?,
    );
    var image = img.decodePng(File(path).readAsBytesSync())!;
    // The capture is in physical pixels of the output.
    final scale = image.width / (view['width']! as num);
    var logicalWidth = (view['width']! as num).toDouble();
    if (rect != null) {
      image = img.copyCrop(
        image,
        x: ((rect['left']! as num) * scale).round(),
        y: ((rect['top']! as num) * scale).round(),
        width: ((rect['width']! as num) * scale).round(),
        height: ((rect['height']! as num) * scale).round(),
      );
      logicalWidth = (rect['width']! as num).toDouble();
    }
    // pixelRatio means what it means for Flutter captures: physical pixels
    // per logical pixel of the picture.
    if (pixelRatio != null && (pixelRatio - scale).abs() > 1e-6) {
      image = img.copyResize(
        image,
        width: math.max(1, (logicalWidth * pixelRatio).round()),
      );
    }
    if (maxWidth != null && image.width > maxWidth) {
      image = img.copyResize(image, width: maxWidth);
    }
    final png = img.encodePng(image);
    File(path).writeAsBytesSync(png);
    return Capture(
      {
        ...info,
        'source': 'compositor',
        'pixelWidth': image.width,
        'pixelHeight': image.height,
      },
      png,
      path,
    );
  }

  Future<Map<String, Object?>> state(String store) async =>
      (await connection.call('state', {'store': store}))!
          as Map<String, Object?>;

  /// Sets the speed animations play at (`timeDilation`: 20 plays them 20
  /// times slower); returns the previous one.
  Future<double> slowdown(double factor) async {
    final previous = await currentSlowdown();
    await connection.call('ext.flutter.timeDilation', {'timeDilation': factor});
    return previous;
  }

  Future<double> currentSlowdown() async {
    final result = await connection.call('ext.flutter.timeDilation');
    return double.parse('${(result! as Map)['timeDilation']}');
  }

  /// A capture of a view, of the part of it a widget covers, or of a region.
  Future<Capture> screenshot({
    int? viewId,
    WidgetQuery? target,
    int index = 0,
    double? pixelRatio,
    int? maxWidth,
    Directory? into,
    String name = 'screenshot',
  }) async {
    final params = <String, Object?>{'viewId': viewId};
    double regionWidth;
    if (target != null && !target.isEmpty) {
      final match = await _match(target, index);
      final rect = match['rect']! as Map;
      params
        ..['viewId'] = match['viewId']
        ..['left'] = rect['left']
        ..['top'] = rect['top']
        ..['width'] = rect['width']
        ..['height'] = rect['height'];
      regionWidth = (rect['width']! as num).toDouble();
    } else {
      final view = await _view(viewId);
      params['viewId'] = view['viewId'];
      regionWidth = (view['width']! as num).toDouble();
    }
    final ratio =
        pixelRatio ??
        (maxWidth == null ? 1.0 : (maxWidth / regionWidth).clamp(0.05, 1.0));
    params['pixelRatio'] = ratio;
    final result = Map<String, Object?>.of(
      (await connection.call('capture', params))! as Map<String, Object?>,
    );
    final png = base64Decode(result.remove('png')! as String);
    final directory = into ?? output.newDirectory(name);
    final file = File(p.join(directory.path, '$name.png'))
      ..writeAsBytesSync(png);
    return Capture(result, png, file.path);
  }

  Future<Map<String, Object?>> _match(WidgetQuery query, int index) async {
    final found = await find(query, limit: index + 1);
    final matches = found['matches']! as List;
    if (index >= matches.length) {
      throw ProbeError('No match #$index for $query (${found['count']} found)');
    }
    final match = matches[index]! as Map<String, Object?>;
    if (match['laidOut'] != true) {
      throw ProbeError('The match for $query is not laid out');
    }
    return match;
  }

  /// Waits until the shell is idle (no frame pending, no animation
  /// running) on several polls in a row, or [timeout] passes; returns
  /// whether it settled. Older shells without `ext.veshell.settled` are
  /// given a fixed delay instead.
  Future<bool> settle({Duration timeout = const Duration(seconds: 5)}) async {
    final deadline = DateTime.now().add(timeout);
    var calm = 0;
    while (DateTime.now().isBefore(deadline)) {
      final Map<String, Object?> state;
      try {
        state = (await connection.call('settled'))! as Map<String, Object?>;
      } on ProbeError {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return false;
      }
      // A blinking caret schedules a frame now and then: idle three polls
      // in a row means nothing is moving.
      calm = state['settled'] == true ? calm + 1 : 0;
      if (calm >= 3) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  /// Whether the instance can freeze and step its animation clock.
  Future<bool> hasClock() async {
    final isolate = await connection.service.getIsolate(connection.isolateId);
    return isolate.extensionRPCs?.contains('ext.veshell.clock') ?? false;
  }

  /// Freezes, steps (by [ms]), resumes or reports the animation clock.
  Future<Map<String, Object?>> clock(String action, {double? ms}) async =>
      (await connection.call('clock', {'action': action, 'ms': ms}))!
          as Map<String, Object?>;

  /// Plays [action] and captures [frames] frames evenly over the next
  /// [duration] of animation time, with the geometry of the [track]ed
  /// widgets on each.
  ///
  /// With a clock the instance can freeze (`exact`, the default when it
  /// can), frame `k` shows exactly `k × duration / (frames − 1)`. Otherwise
  /// the action plays [slowdown] times slower and frames are taken at even
  /// wall-clock intervals, at approximately those times.
  Future<AnimateResult> animate({
    required Map<String, Object?>? action,
    required Duration duration,
    int frames = 9,
    double slowdown = 20,
    bool? exact,
    List<WidgetQuery> track = const [],
    int? viewId,
    WidgetQuery? region,
    double pixelRatio = 0.5,
    String? via,
  }) async {
    if (frames < 2 || frames > maxAnimateFrames) {
      throw ProbeError('Capture between 2 and $maxAnimateFrames frames');
    }
    if (duration <= Duration.zero) {
      throw ProbeError('The duration must be positive');
    }
    if (!slowdown.isFinite || slowdown < 1) {
      throw ProbeError('The slowdown must be at least 1');
    }
    if (!pixelRatio.isFinite || pixelRatio <= 0 || pixelRatio > 4) {
      throw ProbeError('The pixel ratio must be in ]0, 4]');
    }
    final useClock = exact ?? await hasClock();
    final directory = output.newDirectory('animate');
    final records = <Map<String, Object?>>[];
    final images = <Uint8List>[];
    final labels = <String>[];

    Future<void> captureFrame(
      int frameIndex,
      double animationMs, {
      int? wallMs,
    }) async {
      final name = 'frame-${frameIndex.toString().padLeft(2, '0')}';
      final capture = await screenshot(
        viewId: viewId,
        target: region,
        pixelRatio: pixelRatio,
        into: directory,
        name: name,
      );
      final tracked = <String, Object?>{};
      for (final query in track) {
        // One frame's failed lookup must not lose the others.
        try {
          final found = await find(query, limit: 1);
          tracked['$query'] = (found['matches']! as List).firstOrNull;
        } on ProbeError catch (error) {
          tracked['$query'] = {'error': error.message};
        }
      }
      records.add({
        'frame': frameIndex,
        'animationMs': double.parse(animationMs.toStringAsFixed(1)),
        if (wallMs != null) 'wallMs': wallMs,
        'file': capture.path,
        'tracked': tracked,
      });
      images.add(capture.png);
      labels.add(
        '#$frameIndex  t${useClock ? '=' : '~'}${animationMs.round()} ms',
      );
    }

    final stepMs = duration.inMicroseconds / 1000 / (frames - 1);
    if (useClock) {
      // Exact time: animations see only the steps, whatever the speed.
      final previousSlowdown = await this.slowdown(1);
      try {
        await clock('freeze');
        if (action != null) {
          await act(action, via: via);
        }
        // The action's own frame, at the frozen instant.
        await clock('step', ms: 0);
        for (var frameIndex = 0; frameIndex < frames; frameIndex++) {
          if (frameIndex > 0) {
            await clock('step', ms: stepMs);
          }
          await captureFrame(frameIndex, stepMs * frameIndex);
        }
      } finally {
        // Restore the speed even when resuming fails.
        try {
          await clock('resume');
        } finally {
          await this.slowdown(previousSlowdown);
        }
      }
    } else {
      final previous = await this.slowdown(slowdown);
      try {
        if (action != null) {
          await act(action, via: via);
        }
        final clock = Stopwatch()..start();
        final wall = duration * slowdown;
        for (var frameIndex = 0; frameIndex < frames; frameIndex++) {
          final due = wall * frameIndex ~/ (frames - 1);
          final wait = due - clock.elapsed;
          if (wait > Duration.zero) {
            await Future<void>.delayed(wait);
          }
          final elapsed = clock.elapsed;
          await captureFrame(
            frameIndex,
            elapsed.inMicroseconds / 1000 / slowdown,
            wallMs: elapsed.inMilliseconds,
          );
        }
      } finally {
        await this.slowdown(previous);
      }
    }

    final sheet = composeContactSheet(images, labels);
    final sheetPath = p.join(directory.path, 'sheet.png');
    File(sheetPath).writeAsBytesSync(sheet);
    final report = <String, Object?>{
      'directory': directory.path,
      'sheet': sheetPath,
      'mode': useClock ? 'exact' : 'slowdown',
      if (!useClock) 'slowdown': slowdown,
      'durationMs': duration.inMilliseconds,
      'frames': records,
    };
    File(
      p.join(directory.path, 'frames.json'),
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    return AnimateResult(report, sheet, sheetPath);
  }

  /// What the instance prints and logs over the next [duration].
  Future<List<String>> logs(Duration duration) async {
    final service = connection.service;
    final lines = <String>[];
    final subscriptions = <StreamSubscription<Event>>[
      service.onStdoutEvent.listen((event) => lines.add(_decode(event.bytes))),
      service.onStderrEvent.listen((event) => lines.add(_decode(event.bytes))),
      service.onLoggingEvent.listen(
        (event) => lines.add(
          '[${event.logRecord?.loggerName?.valueAsString ?? 'log'}] '
          '${event.logRecord?.message?.valueAsString ?? ''}',
        ),
      ),
    ];
    final streams = [
      EventStreams.kStdout,
      EventStreams.kStderr,
      EventStreams.kLogging,
    ];
    // Only the streams this call subscribes to are cancelled afterwards: a
    // stream this connection already listened to stays as it was.
    final started = <String>[];
    try {
      for (final stream in streams) {
        try {
          await service.streamListen(stream);
          started.add(stream);
        } on RPCError {
          // Already subscribed on this connection.
        }
      }
      await Future<void>.delayed(duration);
    } finally {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      for (final stream in started) {
        await service.streamCancel(stream).catchError((_) => Success());
      }
    }
    return [
      for (final line in lines)
        for (final part in line.split('\n'))
          if (part.trim().isNotEmpty) part,
    ];
  }

  static String _decode(String? base64Bytes) => base64Bytes == null
      ? ''
      : utf8.decode(base64Decode(base64Bytes), allowMalformed: true);
}

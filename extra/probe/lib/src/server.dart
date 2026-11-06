import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:veshell_probe/src/connection.dart';
import 'package:veshell_probe/src/context.dart';
import 'package:veshell_probe/src/isolated.dart';
import 'package:veshell_probe/src/probe.dart';
import 'package:veshell_probe/src/scenario.dart';
import 'package:veshell_probe/src/verify.dart';

/// The protocol version answered when the client asks for none.
const _defaultProtocolVersion = '2025-06-18';

const _target = {
  'type': {
    'type': 'string',
    'description': 'Widget type, e.g. "PersistentApplicationLauncher".',
  },
  'key': {
    'type': 'string',
    'description': "A widget's key (a ValueKey's value), e.g. \"launcher\".",
  },
  'text': {
    'type': 'string',
    'description': 'Text the widget shows (Text, text fields), substring.',
  },
};

const _via = {
  'via': {
    'type': 'string',
    'enum': ['compositor', 'flutter'],
    'description':
        'Input through the compositor, as a device (default when the instance can), or straight into Flutter.',
  },
};

const _allowInput = {
  'allowInput': {
    'type': 'boolean',
    'description':
        "Allow input into an instance the probe did not start (the developer's own session); "
        'the isolated instance always accepts it.',
  },
};

const _url = {
  'url': {
    'type': 'string',
    'description':
        "The instance's VM service URL (e.g. http://127.0.0.1:12347/); found automatically when only one runs.",
  },
};

const _action = {
  'type': 'object',
  'description':
      'One of: {"tap": {"key"|"type"|"text": "...", "index"?: n}} (a found widget); '
      '{"tap": {"x": n, "y": n, "viewId"?: n}} (logical pixels in that view, the '
      'first view when no viewId: not screen coordinates); '
      '{"key": "Enter"} (or "Arrow Down", "Control+Escape"); '
      '{"type": "text", "clear"?: true}.',
};

/// The tools, as listed to the client.
final List<Map<String, Object?>> probeTools = [
  _tool(
    'start',
    'Start an isolated nested Veshell (its own config, data and user directories, the '
        "fixture's applications) and use it for the following calls. Needs a debug build "
        '(cargo build).',
    {
      'fixture': {
        'type': 'string',
        'description':
            'A directory of extra/probe/fixtures (default "$defaultFixture").',
      },
      'windowed': {
        'type': 'boolean',
        'description':
            "A window of the developer's session instead of a headless display (default false).",
      },
      'width': {
        'type': 'integer',
        'description': 'Headless display width (default 1280).',
      },
      'height': {
        'type': 'integer',
        'description': 'Headless display height (default 800).',
      },
    },
  ),
  _tool('stop', 'Stop the isolated instance and delete its directory.', {}),
  _tool(
    'scenario',
    'Run a scenario file (extra/probe/scenarios/*.yaml): its steps on a fresh isolated '
        'headless instance of its own (stop a running one first), then its expectations (find, frames, golden). Returns the '
        'report, with the difference images of failed reference comparisons.',
    {
      'file': {'type': 'string', 'description': 'The scenario file.'},
      'updateGoldens': {
        'type': 'boolean',
        'description': 'Record the screenshots as the new references.',
      },
      'skipGoldens': {
        'type': 'boolean',
        'description':
            'Skip the reference comparisons (another environment than the one that recorded them).',
      },
    },
    required: ['file'],
  ),
  _tool(
    'clock',
    'Freeze the animation clock, step it by an exact duration, resume it, or report it.',
    {
      'action': {
        'type': 'string',
        'enum': ['freeze', 'step', 'resume', 'status'],
      },
      'ms': {'type': 'number', 'description': 'For step: how far.'},
      ..._url,
    },
    required: ['action'],
  ),
  _tool(
    'instances',
    'List running Veshell instances and whether each serves the probe.',
    {},
  ),
  _tool(
    'views',
    "The instance's views (one per monitor): id, logical size, pixel ratio.",
    {..._url},
  ),
  _tool(
    'find',
    'Find widgets by type, key or text: each match with its global rect, the part ancestor '
        'clips leave in view (visibleRect), its opacity and whether it is visible.',
    {
      ..._target,
      'limit': {'type': 'integer'},
      ..._url,
    },
  ),
  _tool(
    'screenshot',
    'Capture what a view painted on its last frame (the whole view, or the region a widget '
        'covers). Returns the image.',
    {
      ..._target,
      'index': {'type': 'integer', 'description': 'Which match to capture.'},
      'viewId': {'type': 'integer'},
      'pixelRatio': {
        'type': 'number',
        'description': 'Defaults to fit 1568 px wide.',
      },
      'source': {
        'type': 'string',
        'enum': ['flutter', 'compositor'],
        'description':
            'flutter: what the shell painted (default); compositor: the composited output, application windows included.',
      },
      ..._url,
    },
  ),
  _tool(
    'act',
    'Perform an action: tap, press a key chord, or type into the focused field.',
    {'action': _action, ..._via, ..._allowInput, ..._url},
    required: ['action'],
  ),
  _tool(
    'animate',
    'Play an action with animations slowed down and capture evenly spaced frames over its '
        'duration: returns a contact sheet image and, per frame, the animation time and the '
        'geometry of the tracked widgets.',
    {
      'action': _action,
      ..._via,
      ..._allowInput,
      'durationMs': {
        'type': 'integer',
        'description': 'Animation time to cover, e.g. 450.',
      },
      'frames': {
        'type': 'integer',
        'description': 'Frames to capture (default 9).',
      },
      'slowdown': {
        'type': 'number',
        'description':
            'Without exact time: how many times slower (default 20).',
      },
      'exact': {
        'type': 'boolean',
        'description':
            'Freeze and step the clock for exact frame times (default: when the instance can).',
      },
      'track': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'Widgets to measure on each frame: "key=launcher", "type=LaunchMorph,text=Alpha".',
      },
      'region': {
        'type': 'string',
        'description': 'Capture only the region of this widget ("key=…").',
      },
      'viewId': {'type': 'integer'},
      ..._url,
    },
    required: ['durationMs'],
  ),
  _tool(
    'state',
    "Snapshot the shell's state: screens, workspaces, windows, or all.",
    {
      'store': {
        'type': 'string',
        'enum': ['all', 'screens', 'workspaces', 'windows'],
      },
      ..._url,
    },
  ),
  _tool(
    'slowdown',
    'Set how many times slower animations play (1 restores the configured speed).',
    {
      'factor': {'type': 'number'},
      ..._url,
    },
    required: ['factor'],
  ),
  _tool(
    'logs',
    'What the instance prints and logs over the next few seconds.',
    {
      'seconds': {'type': 'number', 'description': 'Default 3.'},
      ..._url,
    },
  ),
  _tool(
    'verify',
    'Run the verification gate: cargo check, fmt, test, dart format, flutter test compared '
        'with extra/probe/known_failures.txt. Takes a few minutes.',
    {
      'rust': {
        'type': 'boolean',
        'description': 'Run the cargo steps (default true).',
      },
      'dart': {
        'type': 'boolean',
        'description': 'Run the Dart steps (default true).',
      },
    },
  ),
];

Map<String, Object?> _tool(
  String name,
  String description,
  Map<String, Object?> properties, {
  List<String> required = const [],
}) => {
  'name': name,
  'description': description,
  'inputSchema': {
    'type': 'object',
    'properties': properties,
    if (required.isNotEmpty) 'required': required,
  },
};

/// A tool's answer: text (JSON) and images.
class ToolResult {
  ToolResult(this.json, {this.images = const [], this.isError = false});

  final Object? json;
  final List<List<int>> images;
  final bool isError;

  Map<String, Object?> toJson() => {
    'content': [
      {
        'type': 'text',
        'text': const JsonEncoder.withIndent('  ').convert(json),
      },
      for (final image in images)
        {'type': 'image', 'data': base64Encode(image), 'mimeType': 'image/png'},
    ],
    'isError': isError,
  };
}

/// The pictures a failed scenario report returns inline: each reference
/// difference once, then the contact sheets of its first two animations.
/// None when it passed (the files are in its directory).
List<List<int>> scenarioFailureImages(Map<String, Object?> report) {
  if (report['ok'] == true) {
    return const [];
  }
  final directory = Directory('${report['directory']}');
  final diffs = directory.existsSync()
      ? (directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.diff.png'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : const <File>[];
  final sheets = [
    for (final sheet in (report['animations'] as List? ?? const []).take(2))
      File('$sheet'),
  ].where((file) => file.existsSync());
  return [
    for (final file in [...diffs.take(3), ...sheets]) file.readAsBytesSync(),
  ];
}

/// Runs the tool [name] with [arguments].
Future<ToolResult> callTool(
  ProbeSession session,
  String name,
  Map<String, Object?> arguments,
) async {
  final url = switch (arguments['url']) {
    final String value when value.isNotEmpty => Uri.parse(value),
    _ => null,
  };
  WidgetQuery target() => WidgetQuery(
    type: arguments['type'] as String?,
    key: arguments['key'] as String?,
    text: arguments['text'] as String?,
  );
  try {
    switch (name) {
      case 'instances':
        final instances = await listInstances(
          explicit: url ?? session.url,
          repositoryRoot: session.repositoryRoot,
        );
        final isolated = runningIsolatedInstance(session.repositoryRoot);
        return ToolResult([
          for (final instance in instances)
            {
              ...instance.toJson(),
              if (isolated != null && instance.httpUri == isolated.url)
                'isolated': isolated.toJson(),
            },
        ]);
      case 'start':
        final root = session.repositoryRoot;
        if (root == null) {
          throw ProbeError('Not inside the Veshell repository');
        }
        await session.close();
        final instance = await startIsolatedInstance(
          repositoryRoot: root,
          fixture: arguments['fixture'] as String? ?? defaultFixture,
          headless: arguments['windowed'] != true,
          size: (
            width:
                (arguments['width'] as num?)?.toInt() ??
                defaultHeadlessSize.width,
            height:
                (arguments['height'] as num?)?.toInt() ??
                defaultHeadlessSize.height,
          ),
        );
        return ToolResult(instance.toJson());
      case 'stop':
        final root = session.repositoryRoot;
        if (root == null) {
          throw ProbeError('Not inside the Veshell repository');
        }
        await session.close();
        return ToolResult(await stopIsolatedInstance(root));
      case 'scenario':
        final report = await runScenario(
          session,
          Scenario.load(arguments['file']! as String),
          updateGoldens: arguments['updateGoldens'] == true,
          skipGoldens: arguments['skipGoldens'] == true,
        );
        final images = scenarioFailureImages(report);
        return ToolResult(
          report,
          images: images,
          isError: report['ok'] != true,
        );
      case 'clock':
        return ToolResult(
          await (await session.probe(url: url)).clock(
            arguments['action']! as String,
            ms: (arguments['ms'] as num?)?.toDouble(),
          ),
        );
      case 'views':
        return ToolResult(await (await session.probe(url: url)).views());
      case 'find':
        return ToolResult(
          await (await session.probe(
            url: url,
          )).find(target(), limit: (arguments['limit'] as num?)?.toInt() ?? 20),
        );
      case 'screenshot' when arguments['source'] == 'compositor':
        final capture = await (await session.probe(url: url))
            .compositorScreenshot(
              viewId: (arguments['viewId'] as num?)?.toInt(),
              target: target(),
              index: (arguments['index'] as num?)?.toInt() ?? 0,
              pixelRatio: (arguments['pixelRatio'] as num?)?.toDouble(),
              maxWidth: maxAgentImageWidth,
            );
        return ToolResult(
          {...capture.info, 'file': capture.path},
          images: [capture.png],
        );
      case 'screenshot':
        final capture = await (await session.probe(url: url)).screenshot(
          viewId: (arguments['viewId'] as num?)?.toInt(),
          target: target(),
          index: (arguments['index'] as num?)?.toInt() ?? 0,
          pixelRatio: (arguments['pixelRatio'] as num?)?.toDouble(),
          maxWidth: maxAgentImageWidth,
        );
        return ToolResult(
          {...capture.info, 'file': capture.path},
          images: [capture.png],
        );
      case 'act':
        final action = arguments['action'];
        if (action is! Map<String, Object?>) {
          throw ProbeError('Give an action');
        }
        return ToolResult(
          await (await session.probeForInput(
            url: url,
            allowed: arguments['allowInput'] == true,
          )).act(actionParams(action), via: arguments['via'] as String?),
        );
      case 'animate':
        final action = arguments['action'];
        final region = arguments['region'] as String?;
        final probe = action is Map<String, Object?>
            ? await session.probeForInput(
                url: url,
                allowed: arguments['allowInput'] == true,
              )
            : await session.probe(url: url);
        final result = await probe.animate(
          action: action is Map<String, Object?> ? actionParams(action) : null,
          duration: Duration(
            milliseconds: (arguments['durationMs']! as num).toInt(),
          ),
          frames: (arguments['frames'] as num?)?.toInt() ?? 9,
          slowdown: (arguments['slowdown'] as num?)?.toDouble() ?? 20,
          exact: arguments['exact'] as bool?,
          via: arguments['via'] as String?,
          track: [
            for (final spec in (arguments['track'] as List?) ?? const [])
              WidgetQuery.parse('$spec'),
          ],
          viewId: (arguments['viewId'] as num?)?.toInt(),
          region: region == null ? null : WidgetQuery.parse(region),
        );
        return ToolResult(result.report, images: [result.sheet]);
      case 'state':
        return ToolResult(
          await (await session.probe(
            url: url,
          )).state(arguments['store'] as String? ?? 'all'),
        );
      case 'slowdown':
        final probe = await session.probe(url: url);
        final previous = await probe.slowdown(
          (arguments['factor']! as num).toDouble(),
        );
        return ToolResult({
          'previous': previous,
          'now': await probe.currentSlowdown(),
        });
      case 'logs':
        final seconds = (arguments['seconds'] as num?)?.toDouble() ?? 3;
        return ToolResult(
          await (await session.probe(
            url: url,
          )).logs(Duration(milliseconds: (seconds * 1000).round())),
        );
      case 'verify':
        final root = session.repositoryRoot;
        if (root == null) {
          throw ProbeError('Not inside the Veshell repository');
        }
        final report = await verify(
          root,
          steps: verifySteps(
            root,
            rust: arguments['rust'] as bool? ?? true,
            dart: arguments['dart'] as bool? ?? true,
          ),
          knownFailures: readKnownFailures(
            File(p.join(root, 'extra', 'probe', 'known_failures.txt')),
          ),
        );
        return ToolResult(report, isError: report['ok'] != true);
      default:
        throw ProbeError('Unknown tool "$name"');
    }
  } on ProbeError catch (error) {
    return ToolResult({'error': error.message}, isError: true);
  }
}

/// Serves the tools as JSON-RPC on stdin/stdout until stdin closes.
Future<void> serveTools(ProbeSession session) async {
  void send(Map<String, Object?> message) =>
      stdout.writeln(jsonEncode({'jsonrpc': '2.0', ...message}));

  // One call at a time: the tools share the instance's animation clock.
  var queue = Future<void>.value();
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.trim().isEmpty) {
      continue;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      send({
        'id': null,
        'error': {'code': -32700, 'message': 'Parse error'},
      });
      continue;
    }
    if (decoded is! Map<String, Object?>) {
      send({
        'id': null,
        'error': {'code': -32600, 'message': 'Invalid request'},
      });
      continue;
    }
    final message = decoded;
    // A failing message answers with an error and never stops the queue.
    queue = queue.then((_) async {
      try {
        final reply = await handleToolMessage(session, message);
        if (reply != null) {
          send(reply);
        }
      } on Object catch (error) {
        final id = message['id'];
        if (id != null) {
          send({
            'id': id,
            'error': {'code': -32603, 'message': 'Internal error: $error'},
          });
        }
      }
    });
  }
  await queue;
  // Leave the instance's clock running: a client that exits in the middle of
  // an exact animation would otherwise leave it frozen until the lease ends.
  await session.resumeClock();
  await session.close();
}

/// The reply to one message; `null` for a notification.
Future<Map<String, Object?>?> handleToolMessage(
  ProbeSession session,
  Map<String, Object?> message,
) async {
  final id = message['id'];
  final method = message['method'];
  final params = switch (message['params']) {
    final Map<String, Object?> value => value,
    _ => const <String, Object?>{},
  };
  if (id == null) {
    return null;
  }
  switch (method) {
    case 'initialize':
      return {
        'id': id,
        'result': {
          'protocolVersion':
              params['protocolVersion'] ?? _defaultProtocolVersion,
          'capabilities': {'tools': <String, Object?>{}},
          'serverInfo': {'name': 'veshell-probe', 'version': '0.1.0'},
          'instructions':
              'Probe a debug build of Veshell: find widgets (and whether they are '
              'painted), act through the compositor, capture what is painted, and '
              'play animations at exact, frozen-clock instants (or slowed down). '
              'Prefer `start` (an isolated headless instance); input into any other '
              'instance needs allowInput. See docs/specifications/veshell_probe.md.',
        },
      };
    case 'ping':
      return {'id': id, 'result': <String, Object?>{}};
    case 'tools/list':
      return {
        'id': id,
        'result': {'tools': probeTools},
      };
    case 'tools/call':
      final name = params['name'] as String?;
      final arguments = switch (params['arguments']) {
        final Map<String, Object?> value => value,
        _ => const <String, Object?>{},
      };
      try {
        final result = await callTool(session, name ?? '', arguments);
        return {'id': id, 'result': result.toJson()};
      } on Object catch (error) {
        return {
          'id': id,
          'result': ToolResult({'error': '$error'}, isError: true).toJson(),
        };
      }
    default:
      return {
        'id': id,
        'error': {'code': -32601, 'message': 'Method not found: $method'},
      };
  }
}

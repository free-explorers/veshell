import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:veshell_probe/src/connection.dart';
import 'package:veshell_probe/src/context.dart';
import 'package:veshell_probe/src/server.dart';
import 'package:veshell_probe/src/probe.dart';

const _usage = '''
veshell-probe: see, measure, drive and verify a running Veshell.

Usage: veshell-probe [--url URL] [--allow-input] <command> [options]

Input (tap, key, type, animate's action) only goes into the isolated instance
(`start`) unless --allow-input lets it into another (your own session).

Commands:
  start [--fixture NAME] [--size WxH] [--windowed]
                                  Start an isolated instance, headless (WxH, default
                                  1280x800) or as a window; used by default after.
  stop                            Stop the isolated instance, delete its directory.
  scenario FILE [--update-goldens | --no-goldens]
                                  Run a scenario on a fresh headless instance; check it.
  instances                       List running instances.
  views                           The views (monitors) and their sizes.
  find TARGET                     Widgets matching TARGET, with their geometry.
  screenshot [TARGET] [--compositor]  Capture a view (or a widget's region); --compositor:
                                  the composited output, application windows included.
  tap TARGET | --x X --y Y [--view ID]
                                  Tap a widget (its visible center) or a point, in
                                  logical pixels of a view (the first unless --view),
                                  not of the whole screen.
                                  tap/key/type/animate: --via compositor|flutter (default:
                                  through the compositor, as a device, when it can).
  key CHORD                       Press a key chord: Enter, "Arrow Down", Control+Escape.
  type TEXT [--clear]             Type into the focused text field.
  animate --for MS [ACTION]       Play ACTION slowed down, capture frames over MS.
                                  ACTION: --tap TARGET | --press CHORD | --type TEXT
                                  Options: --frames N --track TARGET… --region TARGET
                                  Exact frames with a freezable clock; else --slowdown X.
  clock freeze|step MS|resume|status  Control the animation clock.
  state [STORE]                   Snapshot the state: all, screens, workspaces, windows.
  slowdown FACTOR                 Play animations FACTOR times slower (1 restores).
  logs [--seconds S]              What the instance prints over the next S seconds.
  verify [--no-rust] [--no-dart]  The verification gate, with the known failures.
  serve                           Serve the commands as JSON-RPC tools on stdio
                                  (for editor integrations).

TARGET is type=…, key=… or text=…, comma separated (e.g. key=launcher);
\\, is a comma inside a value (text=Hello\\, world).
Instances are found from VESHELL_VM_SERVICE_URL, .vscode/vmService.json, or ports 12345+.
''';

/// Runs the command line; returns the exit code.
Future<int> runCli(List<String> arguments) async {
  // Options after the command belong to the command.
  final parser = ArgParser(allowTrailingOptions: false)
    ..addOption('url', help: "The instance's VM service URL.")
    ..addFlag('allow-input', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults global;
  try {
    global = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln('${error.message}\n\n$_usage');
    return 64;
  }
  final rest = global.rest;
  if (global['help'] == true || rest.isEmpty) {
    stdout.write(_usage);
    return rest.isEmpty && global['help'] != true ? 64 : 0;
  }
  final url = global['url'] as String?;
  final session = ProbeSession(
    url: url == null ? null : Uri.parse(url),
    allowInput: global['allow-input'] == true,
  );
  try {
    if (rest.first == 'serve') {
      await serveTools(session);
      return 0;
    }
    final (tool, toolArguments) = _withSharedOptions(
      rest.first,
      rest.skip(1).toList(),
    );
    final result = await callTool(session, tool, toolArguments);
    final out = result.isError ? stderr : stdout;
    out.writeln(const JsonEncoder.withIndent('  ').convert(result.json));
    return result.isError ? 1 : 0;
  } on ProbeError catch (error) {
    stderr.writeln(error.message);
    return 1;
  } on FormatException catch (error) {
    stderr.writeln('${error.message}\n\n$_usage');
    return 64;
  } finally {
    await session.close();
  }
}

/// [_toolCall], with the options several commands share: `--via` (input
/// route, for the commands that send input) and `--compositor` (screenshot
/// source). Other commands keep them, and their own parser refuses them.
(String, Map<String, Object?>) _withSharedOptions(
  String command,
  List<String> arguments,
) {
  final takesVia = const {'tap', 'key', 'type', 'animate'}.contains(command);
  final takesCompositor = command == 'screenshot';
  String? via;
  var compositor = false;
  final remaining = <String>[];
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (takesVia && argument == '--via' && index + 1 < arguments.length) {
      via = arguments[++index];
    } else if (takesVia && argument.startsWith('--via=')) {
      via = argument.substring('--via='.length);
    } else if (takesCompositor && argument == '--compositor') {
      compositor = true;
    } else {
      remaining.add(argument);
    }
  }
  final (tool, toolArguments) = _toolCall(command, remaining);
  return (
    tool,
    {
      ...toolArguments,
      if (via != null) 'via': via,
      if (compositor) 'source': 'compositor',
    },
  );
}

Map<String, Object?> _target(String? spec) {
  if (spec == null) {
    return const {};
  }
  final query = WidgetQuery.parse(spec);
  return {'type': query.type, 'key': query.key, 'text': query.text};
}

(String, Map<String, Object?>) _toolCall(
  String command,
  List<String> arguments,
) {
  String? positional(ArgResults results) =>
      results.rest.isEmpty ? null : results.rest.join(' ');
  switch (command) {
    case 'scenario':
      final results =
          (ArgParser()
                ..addFlag('update-goldens')
                ..addFlag('no-goldens', negatable: false))
              .parse(arguments);
      if (results.rest.isEmpty) {
        throw const FormatException('Give a scenario file');
      }
      return (
        'scenario',
        {
          'file': results.rest.first,
          'updateGoldens': results['update-goldens'] == true,
          'skipGoldens': results['no-goldens'] == true,
        },
      );
    case 'instances' || 'views' || 'stop':
      return (command, const {});
    case 'start':
      final results =
          (ArgParser()
                ..addOption('fixture')
                ..addOption('size')
                ..addFlag('windowed'))
              .parse(arguments);
      final size = (results['size'] as String?)?.split('x');
      return (
        'start',
        {
          'fixture': results['fixture'],
          'windowed': results['windowed'] == true,
          if (size != null && size.length == 2) ...{
            'width': int.parse(size[0]),
            'height': int.parse(size[1]),
          },
        },
      );
    case 'clock':
      if (arguments.isEmpty) {
        throw const FormatException('Give freeze, step MS, resume or status');
      }
      return (
        'clock',
        {
          'action': arguments.first,
          'ms': arguments.length > 1 ? double.parse(arguments[1]) : null,
        },
      );
    case 'find':
      final results = (ArgParser()..addOption('limit')).parse(arguments);
      return (
        'find',
        {
          ..._target(positional(results)),
          'limit': int.tryParse(results['limit'] as String? ?? ''),
        },
      );
    case 'screenshot':
      final results =
          (ArgParser()
                ..addOption('view')
                ..addOption('index')
                ..addOption('pixel-ratio'))
              .parse(arguments);
      return (
        'screenshot',
        {
          ..._target(positional(results)),
          'viewId': int.tryParse(results['view'] as String? ?? ''),
          'index': int.tryParse(results['index'] as String? ?? ''),
          'pixelRatio': double.tryParse(
            results['pixel-ratio'] as String? ?? '',
          ),
        },
      );
    case 'tap':
      final results =
          (ArgParser()
                ..addOption('x')
                ..addOption('y')
                ..addOption('view')
                ..addOption('index'))
              .parse(arguments);
      final x = double.tryParse(results['x'] as String? ?? '');
      final y = double.tryParse(results['y'] as String? ?? '');
      if ((results['x'] != null || results['y'] != null) &&
          (x == null || y == null)) {
        throw const FormatException('tap takes both --x and --y, as numbers');
      }
      return (
        'act',
        {
          'action': {
            'tap': {
              if (x != null && y != null) ...{
                'x': x,
                'y': y,
              } else
                ..._target(positional(results)),
              'viewId': int.tryParse(results['view'] as String? ?? ''),
              'index': int.tryParse(results['index'] as String? ?? ''),
            },
          },
        },
      );
    case 'key':
      return (
        'act',
        {
          'action': {'key': arguments.join(' ')},
        },
      );
    case 'type':
      final results = (ArgParser()..addFlag('clear')).parse(arguments);
      return (
        'act',
        {
          'action': {
            'type': results.rest.join(' '),
            'clear': results['clear'] == true,
          },
        },
      );
    case 'animate':
      final results =
          (ArgParser()
                ..addOption('for', mandatory: true)
                ..addOption('frames')
                ..addOption('slowdown')
                ..addFlag('exact', defaultsTo: null)
                ..addMultiOption('track')
                ..addOption('region')
                ..addOption('view')
                ..addOption('tap')
                ..addOption('press')
                ..addOption('type'))
              .parse(arguments);
      final action = switch ((
        results['tap'],
        results['press'],
        results['type'],
      )) {
        (final String tap, null, null) => {'tap': _target(tap)},
        (null, final String chord, null) => {'key': chord},
        (null, null, final String text) => {'type': text},
        (null, null, null) => null,
        _ => throw const FormatException(
          'Give one of --tap, --press or --type',
        ),
      };
      return (
        'animate',
        {
          'durationMs': int.parse(results['for'] as String),
          'frames': int.tryParse(results['frames'] as String? ?? ''),
          'slowdown': double.tryParse(results['slowdown'] as String? ?? ''),
          'exact': results['exact'],
          'track': results['track'],
          'region': results['region'],
          'viewId': int.tryParse(results['view'] as String? ?? ''),
          'action': action,
        },
      );
    case 'state':
      return ('state', {'store': arguments.firstOrNull ?? 'all'});
    case 'slowdown':
      if (arguments.isEmpty) {
        throw const FormatException('Give a factor');
      }
      return ('slowdown', {'factor': double.parse(arguments.first)});
    case 'logs':
      final results = (ArgParser()..addOption('seconds')).parse(arguments);
      return (
        'logs',
        {'seconds': double.tryParse(results['seconds'] as String? ?? '')},
      );
    case 'verify':
      final results =
          (ArgParser()
                ..addFlag('rust', defaultsTo: true)
                ..addFlag('dart', defaultsTo: true))
              .parse(arguments);
      return ('verify', {'rust': results['rust'], 'dart': results['dart']});
    default:
      throw FormatException('Unknown command "$command"');
  }
}

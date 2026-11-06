import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:veshell_probe/src/cli.dart';
import 'package:veshell_probe/src/compositor.dart';
import 'package:veshell_probe/src/connection.dart';
import 'package:veshell_probe/src/contact_sheet.dart';
import 'package:veshell_probe/src/context.dart';
import 'package:veshell_probe/src/isolated.dart';
import 'package:veshell_probe/src/server.dart';
import 'package:veshell_probe/src/probe.dart';
import 'package:veshell_probe/src/scenario.dart';
import 'package:veshell_probe/src/verify.dart';

void main() {
  group('addresses', () {
    test('normalize to the HTTP address, websocket ones too', () {
      expect(
        normalizeHttpUri(Uri.parse('http://127.0.0.1:12347')),
        Uri.parse('http://127.0.0.1:12347/'),
      );
      expect(
        normalizeHttpUri(Uri.parse('ws://127.0.0.1:12347/ws')),
        Uri.parse('http://127.0.0.1:12347/'),
      );
      expect(
        webSocketUri(Uri.parse('http://127.0.0.1:12347/')),
        Uri.parse('ws://127.0.0.1:12347/ws'),
      );
    });

    test('an explicit address is the only candidate', () async {
      expect(await candidateUris(explicit: Uri.parse('http://127.0.0.1:1/')), [
        Uri.parse('http://127.0.0.1:1/'),
      ]);
    });

    test('the environment and .vscode/vmService.json are candidates', () async {
      final root = Directory.systemTemp.createTempSync('probe-root');
      addTearDown(() => root.deleteSync(recursive: true));
      Directory(p.join(root.path, '.vscode')).createSync();
      File(
        p.join(root.path, '.vscode', 'vmService.json'),
      ).writeAsStringSync('{"uri":"http://127.0.0.1:2/"}');
      final candidates = await candidateUris(
        environment: {'VESHELL_VM_SERVICE_URL': 'http://127.0.0.1:1'},
        repositoryRoot: root.path,
      );
      expect(candidates.take(2), [
        Uri.parse('http://127.0.0.1:1/'),
        Uri.parse('http://127.0.0.1:2/'),
      ]);
    });
  });

  group('targets and actions', () {
    test('parse type, key and text criteria', () {
      final query = WidgetQuery.parse('type=AppEntry,text=Fire fox');
      expect(query.type, 'AppEntry');
      expect(query.text, 'Fire fox');
      expect(query.key, isNull);
      expect('$query', 'type=AppEntry,text=Fire fox');
      expect(() => WidgetQuery.parse('color=red'), throwsA(isA<ProbeError>()));
      expect(() => WidgetQuery.parse('launcher'), throwsA(isA<ProbeError>()));
    });

    test('a backslash escapes a comma in a value', () {
      final query = WidgetQuery.parse(r'text=Hello\, world,type=Text');
      expect(query.text, 'Hello, world');
      expect(query.type, 'Text');
      expect(WidgetQuery.parse(r'text=a\\b').text, r'a\b');
    });

    test(
      'the command line keeps options to the commands that take them',
      () async {
        // find takes no --via, tap no half point: usage errors, before any
        // instance is looked for.
        expect(await runCli(['find', '--via', 'flutter', 'key=a']), 64);
        expect(await runCli(['tap', '--x', '10']), 64);
      },
    );

    test('actions become act parameters', () {
      expect(actionParams({'key': 'Enter'}), {'action': 'key', 'key': 'Enter'});
      expect(actionParams({'type': 'fire'}), {
        'action': 'type',
        'text': 'fire',
        'clear': false,
      });
      expect(
        actionParams({
          'tap': {'key': 'launcher'},
        }),
        {'action': 'tap', 'key': 'launcher'},
      );
      expect(() => actionParams({'dance': true}), throwsA(isA<ProbeError>()));
    });
  });

  group('verify', () {
    const report = '''
00:24 +859 -7: /repo/src/shell/test/ephemeral_window_focus_test.dart: clicking the window hands it the keyboard [E]
00:24 +860 -7: /repo/src/shell/test/environment_variables_editor_test.dart: stages rows [E]
00:24 +861 -8: loading /repo/src/shell/test/broken_test.dart [E]
00:25 +864 -8: Some tests failed.
''';

    test('reads the failing tests of an expanded report', () {
      expect(failingTests(report), {
        'ephemeral_window_focus_test.dart: clicking the window hands it the keyboard',
        'environment_variables_editor_test.dart: stages rows',
        'loading broken_test.dart',
      });
    });

    test('reads the known failures, without comments', () {
      final file = File(
        p.join(Directory.systemTemp.createTempSync().path, 'known'),
      )..writeAsStringSync('# a comment\n\nfile.dart: a test\n');
      addTearDown(() => file.parent.deleteSync(recursive: true));
      expect(readKnownFailures(file), {'file.dart: a test'});
      expect(readKnownFailures(File('/nonexistent')), isEmpty);
    });

    test('the gate covers Rust and Dart, or either', () {
      expect(verifySteps('/repo').map((step) => step.name), [
        'cargo check',
        'cargo fmt',
        'cargo test',
        'dart format',
        'flutter test',
        'probe pub get',
        'probe format',
        'probe analyze',
        'probe test',
      ]);
      expect(verifySteps('/repo', dart: false).map((step) => step.name), [
        'cargo check',
        'cargo fmt',
        'cargo test',
      ]);
    });

    test('the repository known failures parse', () {
      final root = findRepositoryRoot();
      expect(root, isNotNull);
      final known = readKnownFailures(
        File(p.join(root!, 'extra', 'probe', 'known_failures.txt')),
      );
      expect(known, isNotEmpty);
      expect(known.every((line) => line.contains('.dart: ')), isTrue);
    });
  });

  test('a contact sheet lays frames out in a labelled grid', () {
    Uint8List frame(int red) => img.encodePng(
      img.Image(width: 960, height: 540)..clear(img.ColorRgb8(red, 0, 0)),
    );
    final sheet = img.decodePng(
      composeContactSheet(
        [frame(255), frame(128), frame(64), frame(0)],
        ['#0', '#1', '#2', '#3'],
      ),
    )!;
    // Three columns of 480 px wide cells (scaled from 960), two rows.
    expect(sheet.width, 3 * contactSheetCellWidth + 4 * 4);
    expect(sheet.height, 2 * 270 + 3 * 4);
    // The second cell's middle is its frame's red.
    final pixel = sheet.getPixel(4 + 480 + 4 + 240, 4 + 135);
    expect(pixel.r, 128);
  });

  group('tool server', () {
    final session = ProbeSession(repositoryRoot: '/nonexistent');

    test('initializes with the client protocol version', () async {
      final reply = (await handleToolMessage(session, {
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': '2025-03-26'},
      }))!;
      final result = reply['result']! as Map;
      expect(result['protocolVersion'], '2025-03-26');
      expect((result['capabilities']! as Map).containsKey('tools'), isTrue);
    });

    test('lists every tool with an object schema', () async {
      final reply = (await handleToolMessage(session, {
        'id': 2,
        'method': 'tools/list',
      }))!;
      final tools = (reply['result']! as Map)['tools']! as List;
      expect(
        tools.map((tool) => (tool as Map)['name']),
        containsAll(['find', 'animate', 'verify']),
      );
      for (final tool in tools.cast<Map>()) {
        expect((tool['inputSchema']! as Map)['type'], 'object');
      }
    });

    test('ignores notifications and rejects unknown methods', () async {
      expect(
        await handleToolMessage(session, {
          'method': 'notifications/initialized',
        }),
        isNull,
      );
      final reply = (await handleToolMessage(session, {
        'id': 3,
        'method': 'nope',
      }))!;
      expect((reply['error']! as Map)['code'], -32601);
    });

    test('a failing tool is an error result, not a protocol error', () async {
      final reply = (await handleToolMessage(session, {
        'id': 4,
        'method': 'tools/call',
        'params': {'name': 'no-such-tool', 'arguments': <String, Object?>{}},
      }))!;
      final result = reply['result']! as Map;
      expect(result['isError'], isTrue);
      expect('${(result['content']! as List).first}', contains('Unknown tool'));
    });

    test('malformed params are tolerated, not thrown', () async {
      final reply = (await handleToolMessage(session, {
        'id': 5,
        'method': 'tools/call',
        'params': {'name': 'no-such-tool', 'arguments': 'oops'},
      }))!;
      expect((reply['result']! as Map)['isError'], isTrue);
      final listed = (await handleToolMessage(session, {
        'id': 6,
        'method': 'tools/list',
        'params': 'oops',
      }))!;
      expect(listed['result'], isNotNull);
    });
  });

  group('isolated instance', () {
    test('its environment keeps it in its own directory', () {
      final environment = isolatedEnvironment(
        base: {
          'HOME': '/home/me',
          'WAYLAND_DISPLAY': 'wayland-1',
          'XDG_SESSION_ID': '2',
          'XDG_SEAT': 'seat0',
          'XDG_VTNR': '2',
          'VESHELL_VM_SERVICE_URL': 'http://127.0.0.1:12346/',
          'VESHELL_VSCODE_DEBUG': 'true',
          'XDG_DATA_DIRS': '/usr/local/share:/usr/share',
        },
        root: '/tmp/veshell-probe-x',
        fixtureShare: '/repo/extra/probe/fixtures/two-apps/share',
      );
      expect(environment['VESHELL_CONFIG_DIR'], '/tmp/veshell-probe-x/config');
      expect(environment['XDG_CONFIG_HOME'], '/tmp/veshell-probe-x/xdg-config');
      expect(environment['XDG_DATA_HOME'], '/tmp/veshell-probe-x/xdg-data');
      expect(
        environment['XDG_DATA_DIRS'],
        '/repo/extra/probe/fixtures/two-apps/share:/tmp/veshell-probe-x/system-share',
      );
      expect(environment['VESHELL_BACKEND'], 'winit');
      // The host's system bus is shared: the shell only reads it, and no
      // login session, seat or VT is the instance's.
      expect(environment['VESHELL_PROBE_ISOLATED'], '1');
      for (final name in ['XDG_SESSION_ID', 'XDG_SEAT', 'XDG_VTNR']) {
        expect(environment.containsKey(name), isFalse, reason: name);
      }
      // Its own home and session bus: nothing written to the user's, no
      // media keys or notifications exchanged with the user's session.
      expect(environment['HOME'], '/tmp/veshell-probe-x/home');
      expect(
        environment['DBUS_SESSION_BUS_ADDRESS'],
        'unix:path=/tmp/veshell-probe-x/bus',
      );
      // The display to nest in is kept; the parent's probe address is not,
      // nor what would make it rewrite .vscode/vmService.json.
      expect(environment['WAYLAND_DISPLAY'], 'wayland-1');
      expect(environment.containsKey('VESHELL_VM_SERVICE_URL'), isFalse);
      expect(environment.containsKey('VESHELL_VSCODE_DEBUG'), isFalse);
    });

    test('its processes are told apart by its directory, not their name', () {
      final program = p.basename(
        File('/proc/$pid/cmdline').readAsStringSync().split('\u0000').first,
      );
      expect(isOwnProcess(pid, program), isTrue);
      // The same program, but not started for this instance.
      expect(
        isOwnProcess(pid, program, marker: 'veshell-probe-not-this-one'),
        isFalse,
      );
      expect(isOwnProcess(pid, 'not-$program'), isFalse);
    });

    test('its user directories and shared system data are laid out', () {
      final root = Directory.systemTemp.createTempSync('veshell-probe-test');
      addTearDown(() => root.deleteSync(recursive: true));
      final system = Directory(p.join(root.path, 'system'))..createSync();
      for (final name in ['icons', 'fonts', 'applications']) {
        Directory(p.join(system.path, name)).createSync();
      }
      final instance = p.join(root.path, 'instance');
      prepareIsolatedRoot(instance, systemShare: system.path);

      final userDirs = File(
        p.join(instance, 'xdg-config', 'user-dirs.dirs'),
      ).readAsStringSync();
      expect(
        userDirs,
        contains('XDG_VIDEOS_DIR="${p.join(instance, 'home', 'Videos')}"'),
      );
      expect(
        Directory(p.join(instance, 'home', 'Videos')).existsSync(),
        isTrue,
      );
      // The system's icons and fonts, never its applications.
      final shared = Directory(
        p.join(instance, 'system-share'),
      ).listSync().map((entry) => p.basename(entry.path)).toSet();
      expect(shared, {'icons', 'fonts'});
    });

    test('no recorded instance means none running', () {
      final root = Directory.systemTemp.createTempSync('probe-root');
      addTearDown(() => root.deleteSync(recursive: true));
      expect(runningIsolatedInstance(root.path), isNull);
      expect(runningIsolatedInstance(null), isNull);
    });
  });

  group('compositor input', () {
    test('a chord presses its keys in order and releases them in reverse', () {
      expect(chordEvents('Super+Q'), [
        {'type': 'key', 'key': 'super', 'state': 'pressed'},
        {'type': 'key', 'key': 'q', 'state': 'pressed'},
        {'type': 'key', 'key': 'q', 'state': 'released'},
        {'type': 'key', 'key': 'super', 'state': 'released'},
      ]);
      expect(chordEvents('Arrow Down').first['key'], 'arrowdown');
      expect(() => chordEvents('+'), throwsA(isA<ProbeError>()));
    });

    test('typing shifts capitals and maps spaces', () {
      final keys = [
        for (final event in typingEvents('Ab 1'))
          if (event['state'] == 'pressed') event['key'],
      ];
      expect(keys, ['shift', 'a', 'b', 'space', '1']);
      expect(() => typingEvents('a.b'), throwsA(isA<ProbeError>()));
    });

    test('a click moves, presses and releases', () {
      expect(clickEvents(10, 20).map((event) => event['type']), [
        'motion',
        'button',
        'button',
      ]);
      expect(clickEvents(10, 20).first, {
        'type': 'motion',
        'x': 10.0,
        'y': 20.0,
      });
    });
  });

  group('scenarios', () {
    File write(String content) {
      final directory = Directory.systemTemp.createTempSync('scenario');
      addTearDown(() => directory.deleteSync(recursive: true));
      return File(p.join(directory.path, 'example.yaml'))
        ..writeAsStringSync(content);
    }

    test('load with their defaults', () {
      final file = write('''
steps:
  - type: be
expect:
  - find: text=Beta
    visible: true
''');
      final scenario = Scenario.load(file.path);
      expect(scenario.name, 'example');
      expect(scenario.fixture, defaultFixture);
      expect(scenario.size, defaultHeadlessSize);
      expect(scenario.steps, [
        {'type': 'be'},
      ]);
      expect(scenario.expectations.single['visible'], isTrue);
      expect(
        scenario.goldenDirectory,
        p.join(file.parent.path, 'goldens', 'example'),
      );
    });

    test('read their size and reject what is not a scenario', () {
      expect(Scenario.load(write('size: 800x600').path).size, (
        width: 800,
        height: 600,
      ));
      expect(
        () => Scenario.load(write('- a list').path),
        throwsA(isA<ProbeError>()),
      );
      expect(
        () => Scenario.load(write('steps: 3').path),
        throwsA(isA<ProbeError>()),
      );
      for (final size in ['big', '800x', '0x600', '800x600x2']) {
        expect(
          () => Scenario.load(write('size: $size').path),
          throwsA(isA<ProbeError>()),
          reason: size,
        );
      }
    });

    test('never run on an instance an explicit URL names', () async {
      // It would send its input there: refused before anything starts.
      final session = ProbeSession(
        url: Uri.parse('http://127.0.0.1:1/'),
        repositoryRoot: findRepositoryRoot(),
      );
      await expectLater(
        runScenario(session, Scenario.load(write('steps: []').path)),
        throwsA(
          isA<ProbeError>().having(
            (e) => e.message,
            'message',
            contains('--url'),
          ),
        ),
      );
    });

    test('a failed report returns each difference once, then its sheets', () {
      final directory = Directory.systemTemp.createTempSync('report');
      addTearDown(() => directory.deleteSync(recursive: true));
      File write(String name) =>
          File(p.join(directory.path, name))..writeAsBytesSync([name.length]);
      write('a.png');
      write('a.diff.png');
      final sheet = write('sheet.png');
      final report = {
        'ok': false,
        'directory': directory.path,
        'animations': [sheet.path],
      };
      expect(scenarioFailureImages(report), hasLength(2));
      expect(scenarioFailureImages({...report, 'ok': true}), isEmpty);
    });

    test('the repository scenarios load', () {
      final directory = Directory(
        p.join(findRepositoryRoot()!, 'extra', 'probe', 'scenarios'),
      );
      final files = directory.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.yaml'),
      );
      expect(files, isNotEmpty);
      for (final file in files) {
        expect(Scenario.load(file.path).steps, isNotEmpty, reason: file.path);
      }
    });
  });

  group('reference comparison', () {
    img.Image square(int red) =>
        img.Image(width: 10, height: 10)..clear(img.ColorRgb8(red, 0, 0));

    test('identical images do not differ', () {
      final comparison = compareImages(square(100), square(100));
      expect(comparison.sameSize, isTrue);
      expect(comparison.differing, 0);
    });

    test('counts the pixels beyond the channel threshold', () {
      final actual = square(100)
        ..setPixelRgb(0, 0, 200, 0, 0)
        ..setPixelRgb(1, 0, 100 + goldenChannelThreshold, 0, 0);
      final comparison = compareImages(square(100), actual);
      // The second pixel is within the threshold.
      expect(comparison.differing, 0.01);
      expect(comparison.diff!.getPixel(0, 0).r, 255);
    });

    test('different sizes never match', () {
      final comparison = compareImages(
        square(100),
        img.Image(width: 5, height: 10),
      );
      expect(comparison.sameSize, isFalse);
      expect(comparison.actualSize, '5x10');
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:veshell_probe/src/connection.dart';
import 'package:veshell_probe/src/context.dart';
import 'package:veshell_probe/src/isolated.dart';
import 'package:veshell_probe/src/probe.dart';
import 'package:yaml/yaml.dart';

/// A channel differing by more than this (out of 255) makes a pixel differ
/// from its reference.
const goldenChannelThreshold = 24;

/// The share of differing pixels a reference comparison tolerates by
/// default.
const defaultGoldenTolerance = 0.002;

/// A reproducible check of the shell (see
/// `docs/specifications/veshell_probe.md`): a fixture, steps, expectations.
class Scenario {
  Scenario({
    required this.name,
    required this.file,
    required this.fixture,
    required this.size,
    required this.via,
    required this.steps,
    required this.expectations,
  });

  /// Reads the scenario in [file].
  factory Scenario.load(String file) {
    final Object? document;
    try {
      document = jsonDecode(
        jsonEncode(loadYaml(File(file).readAsStringSync())),
      );
    } on Object catch (error) {
      throw ProbeError('Cannot read the scenario $file: $error');
    }
    if (document is! Map<String, Object?>) {
      throw ProbeError('A scenario is a map: name, fixture, steps, expect');
    }
    final size = switch (document['size']) {
      null => defaultHeadlessSize,
      final Object spec => switch (RegExp(
        r'^(\d+)x(\d+)$',
      ).firstMatch('$spec')) {
        final match?
            when int.parse(match[1]!) > 0 && int.parse(match[2]!) > 0 =>
          (width: int.parse(match[1]!), height: int.parse(match[2]!)),
        _ => throw ProbeError('size is WIDTHxHEIGHT, not $spec'),
      },
    };
    List<Map<String, Object?>> list(Object? value, String what) =>
        switch (value) {
          null => const [],
          final List<Object?> items => [
            for (final item in items)
              if (item is Map<String, Object?>)
                item
              else
                throw ProbeError('Each of $what is a map, not $item'),
          ],
          _ => throw ProbeError('$what is a list'),
        };
    return Scenario(
      name: document['name'] as String? ?? p.basenameWithoutExtension(file),
      file: file,
      fixture: document['fixture'] as String? ?? defaultFixture,
      size: size,
      via: document['via'] as String?,
      steps: list(document['steps'], 'steps'),
      expectations: list(document['expect'], 'expect'),
    );
  }

  final String name;
  final String file;
  final String fixture;
  final ({int width, int height}) size;

  /// How the steps' input is delivered (`compositor` or `flutter`); the
  /// probe's default when null.
  final String? via;
  final List<Map<String, Object?>> steps;
  final List<Map<String, Object?>> expectations;

  /// Where its reference frames live: next to it, in
  /// `goldens/<scenario file name>/`.
  String get goldenDirectory =>
      p.join(p.dirname(file), 'goldens', p.basenameWithoutExtension(file));
}

/// Runs [scenario] on the running isolated instance, or on one started for
/// it (headless, its fixture and size) and stopped after; returns the report.
Future<Map<String, Object?>> runScenario(
  ProbeSession session,
  Scenario scenario, {
  bool updateGoldens = false,
  bool skipGoldens = false,
}) async {
  final root = session.repositoryRoot;
  if (root == null) {
    throw ProbeError('Not inside the Veshell repository');
  }
  // A scenario sends input: it runs on an isolated instance, never on the
  // instance an explicit URL names (which may be the developer's session).
  if (session.url != null) {
    throw ProbeError(
      'A scenario runs on an isolated instance of its own: drop --url',
    );
  }
  // Always a fresh instance: one left running carries the state of whatever
  // was done in it (a panel open, a field typed into), which a scenario
  // must not depend on. Only one isolated instance runs at a time.
  if (runningIsolatedInstance(root) case final running?) {
    throw ProbeError(
      'A scenario starts an isolated instance of its own, and one already '
      'runs (pid ${running.pid}, ${running.url}): stop it first',
    );
  }
  await session.close();
  final instance = await startIsolatedInstance(
    repositoryRoot: root,
    fixture: scenario.fixture,
    size: scenario.size,
  );
  try {
    final probe = await session.probe(url: instance.url);
    final directory = session.output.newDirectory(
      'scenario-${p.basenameWithoutExtension(scenario.file)}',
    );
    final run = _ScenarioRun(probe, scenario, directory);
    await run.playSteps();
    final results = [
      for (final expectation in scenario.expectations)
        if (skipGoldens && expectation.containsKey('golden'))
          {
            'expect': expectation,
            'ok': true,
            'skipped': true,
            'detail':
                'reference comparison skipped (references are recorded per '
                'environment: fonts render differently across distributions)',
          }
        else
          await run.check(expectation, updateGoldens: updateGoldens),
    ];
    final report = <String, Object?>{
      'scenario': scenario.name,
      'file': scenario.file,
      'ok': results.every((result) => result['ok'] == true),
      'directory': directory.path,
      'failures': [
        for (final result in results)
          if (result['ok'] != true) result,
      ],
      'screenshots': run.screenshots,
      'animations': [
        for (final animation in run.animations) animation['sheet'],
      ],
      'results': results,
    };
    File(
      p.join(directory.path, 'report.json'),
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    return report;
  } finally {
    await session.close();
    await stopIsolatedInstance(root);
  }
}

class _ScenarioRun {
  _ScenarioRun(this.probe, this.scenario, this.directory);

  final Probe probe;
  final Scenario scenario;
  final Directory directory;
  final Map<String, String> screenshots = {};
  final List<Map<String, Object?>> animations = [];

  Future<void> playSteps() async {
    for (final (index, step) in scenario.steps.indexed) {
      try {
        await _play(step);
      } on ProbeError catch (error) {
        throw ProbeError(
          'Step #$index ${jsonEncode(step)} failed: ${error.message}',
        );
      }
    }
  }

  Future<void> _play(Map<String, Object?> step) async {
    final via = step['via'] as String? ?? scenario.via;
    if (step['wait_for'] case final Map<String, Object?> condition) {
      await _waitFor(condition);
    } else if (step.containsKey('settle')) {
      await probe.settle();
    } else if (step.containsKey('wait')) {
      await Future<void>.delayed(
        Duration(milliseconds: (step['wait']! as num).toInt()),
      );
    } else if (step.containsKey('screenshot')) {
      final spec = step['screenshot'];
      final options = spec is Map<String, Object?>
          ? spec
          : <String, Object?>{'name': spec};
      final name =
          options['name'] as String? ?? 'screenshot-${screenshots.length}';
      final target = options['target'] == null
          ? null
          : WidgetQuery.parse('${options['target']}');
      // Compared with references: never catch the shell mid-change.
      if (options['settle'] != false) {
        await probe.settle();
      }
      final capture = options['compositor'] == true
          ? await probe.compositorScreenshot(
              target: target,
              into: directory,
              name: name,
            )
          : await probe.screenshot(target: target, into: directory, name: name);
      screenshots[name] = capture.path;
    } else if (step.containsKey('animate')) {
      final options = step['animate']! as Map<String, Object?>;
      final result = await probe.animate(
        action: _action(options),
        duration: Duration(milliseconds: (options['for']! as num).toInt()),
        frames: (options['frames'] as num?)?.toInt() ?? 9,
        track: [
          for (final spec in (options['track'] as List?) ?? const [])
            WidgetQuery.parse('$spec'),
        ],
        region: options['region'] == null
            ? null
            : WidgetQuery.parse('${options['region']}'),
        via: options['via'] as String? ?? via,
      );
      animations.add(result.report);
    } else {
      final action = _action(step);
      if (action == null) {
        throw ProbeError(
          'A step is tap, key, type, wait, screenshot or animate: ${jsonEncode(step)}',
        );
      }
      await probe.act(action, via: via);
    }
  }

  /// Polls a `find` condition (as in `expect`: `count`, `visible`, `painted`)
  /// until it holds, or fails after `timeout` ms (default 10000): the shell
  /// loads asynchronously (the applications, a launched tile), so a step
  /// waits for what it needs rather than for a fixed time.
  Future<void> _waitFor(Map<String, Object?> condition) async {
    final timeout = Duration(
      milliseconds: (condition['timeout'] as num?)?.toInt() ?? 10000,
    );
    final deadline = DateTime.now().add(timeout);
    Map<String, Object?> last;
    do {
      last = await _checkFind(condition);
      if (last['ok'] == true) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    } while (DateTime.now().isBefore(deadline));
    throw ProbeError(
      'Waited $timeout for ${jsonEncode(condition)}: ${last['detail']}',
    );
  }

  /// The `act` parameters of a step's (or an animate step's) action, if any.
  Map<String, Object?>? _action(Map<String, Object?> step) {
    if (step['tap'] case final Object tap) {
      final target = switch (tap) {
        final String spec => WidgetQuery.parse(spec).toParams(),
        final Map<String, Object?> fields => fields,
        _ => throw ProbeError('tap is a target ("key=…") or a map'),
      };
      return {'action': 'tap', ...target};
    }
    if (step['key'] case final String chord) {
      return {'action': 'key', 'key': chord};
    }
    switch (step['type']) {
      case final String text:
        return {'action': 'type', 'text': text};
      case {'text': final String text}:
        return {
          'action': 'type',
          'text': text,
          'clear': (step['type']! as Map)['clear'] == true,
        };
      case final Object other:
        throw ProbeError('type is a text or {text, clear}, not $other');
    }
    return null;
  }

  Future<Map<String, Object?>> check(
    Map<String, Object?> expectation, {
    required bool updateGoldens,
  }) async {
    try {
      if (expectation.containsKey('golden')) {
        return await _checkGolden(expectation, updateGoldens: updateGoldens);
      }
      if (expectation.containsKey('animation') ||
          expectation.containsKey('frames')) {
        return _checkFrames(expectation);
      }
      if (expectation.containsKey('find')) {
        return await _checkFind(expectation);
      }
      return _result(
        expectation,
        false,
        'An expectation is find, frames or golden',
      );
    } on ProbeError catch (error) {
      return _result(expectation, false, error.message);
    }
  }

  Map<String, Object?> _result(
    Map<String, Object?> expectation,
    bool ok,
    String detail,
  ) => {'expect': expectation, 'ok': ok, 'detail': detail};

  Future<Map<String, Object?>> _checkFind(
    Map<String, Object?> expectation,
  ) async {
    final query = WidgetQuery.parse('${expectation['find']}');
    final found = await probe.find(query, limit: 1);
    final count = found['count']! as int;
    if (expectation['count'] case final num wanted) {
      return _result(
        expectation,
        count == wanted,
        '$count found, $wanted expected',
      );
    }
    final match =
        (found['matches']! as List).firstOrNull as Map<String, Object?>?;
    return _compareMatch(expectation, match, '$query');
  }

  Map<String, Object?> _compareMatch(
    Map<String, Object?> expectation,
    Map<String, Object?>? match,
    String what,
  ) {
    // Without a match, only an expectation of absence (visible or painted
    // false) can pass: a bare find means "it is there".
    if (match == null &&
        expectation['visible'] != false &&
        expectation['painted'] != false) {
      return _result(expectation, false, '$what is not there');
    }
    for (final property in ['visible', 'painted']) {
      if (expectation[property] case final bool wanted) {
        final actual = match?[property] == true;
        if (actual != wanted) {
          return _result(
            expectation,
            false,
            match == null
                ? '$what is not there'
                : '$what $property is $actual, $wanted expected',
          );
        }
      }
    }
    return _result(expectation, true, '$what as expected');
  }

  Map<String, Object?> _checkFrames(Map<String, Object?> expectation) {
    if (animations.isEmpty) {
      throw ProbeError('No animate step to check');
    }
    final index =
        (expectation['animation'] as num?)?.toInt() ?? animations.length - 1;
    if (index < 0 || index >= animations.length) {
      throw ProbeError('No animation #$index (${animations.length})');
    }
    final frames = (animations[index]['frames']! as List)
        .cast<Map<String, Object?>>();
    final selected = _selectFrames(expectation['frames'], frames.length);
    final target = '${expectation['find']}';
    final key = '${WidgetQuery.parse(target)}';
    final matches = [
      for (final frame in selected)
        (
          frame,
          (frames[frame]['tracked']! as Map)[key] as Map<String, Object?>?,
        ),
    ];
    if (!(frames.first['tracked']! as Map).containsKey(key)) {
      throw ProbeError('$target is not tracked by animation #$index');
    }
    for (final (frame, match) in matches) {
      final result = _compareMatch(
        expectation,
        match,
        '$target on frame $frame',
      );
      if (result['ok'] != true) {
        return result;
      }
    }
    if (expectation['unchanged'] case final List<Object?> properties) {
      for (final property in properties.cast<String>()) {
        double? value(Map<String, Object?>? match) =>
            ((match?['rect'] as Map?)?[property] as num?)?.toDouble();
        final first = value(matches.first.$2);
        for (final (frame, match) in matches) {
          if (value(match) == null) {
            return _result(
              expectation,
              false,
              '$target has no $property on frame $frame',
            );
          }
          if (value(match) != first) {
            return _result(
              expectation,
              false,
              '$target $property changed on frame $frame: ${value(match)} (was $first)',
            );
          }
        }
      }
    }
    return _result(
      expectation,
      true,
      '$target as expected on frames $selected',
    );
  }

  /// The frames `all`, `first`, `last`, `N` or `A-B` designate.
  List<int> _selectFrames(Object? spec, int count) {
    final (first, last) = switch (spec) {
      null || 'all' => (0, count - 1),
      'first' => (0, 0),
      'last' => (count - 1, count - 1),
      final int frame => (frame, frame),
      final String range => switch (RegExp(
        r'^(\d+)-(\d+)$',
      ).firstMatch(range.trim())) {
        final match? => (int.parse(match[1]!), int.parse(match[2]!)),
        _ => throw ProbeError(
          'frames is all, first, last, N or A-B, not $spec',
        ),
      },
      _ => throw ProbeError('frames is all, first, last, N or A-B, not $spec'),
    };
    if (first < 0 || last >= count || first > last) {
      throw ProbeError('frames $spec is not within 0-${count - 1}');
    }
    return [for (var frame = first; frame <= last; frame++) frame];
  }

  Future<Map<String, Object?>> _checkGolden(
    Map<String, Object?> expectation, {
    required bool updateGoldens,
  }) async {
    final name = '${expectation['golden']}';
    final shot = screenshots[name];
    if (shot == null) {
      throw ProbeError('No screenshot named "$name"');
    }
    final golden = File(p.join(scenario.goldenDirectory, '$name.png'));
    if (updateGoldens) {
      golden
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(File(shot).readAsBytesSync());
      return _result(expectation, true, 'reference updated: ${golden.path}');
    }
    if (!golden.existsSync()) {
      throw ProbeError(
        'No reference ${golden.path}: run with --update-goldens to record it',
      );
    }
    final tolerance =
        (expectation['tolerance'] as num?)?.toDouble() ??
        defaultGoldenTolerance;
    final comparison = compareImages(
      img.decodePng(golden.readAsBytesSync())!,
      img.decodePng(File(shot).readAsBytesSync())!,
    );
    if (comparison.diff case final diff?) {
      File(
        p.join(directory.path, '$name.diff.png'),
      ).writeAsBytesSync(img.encodePng(diff));
    }
    final ok = comparison.sameSize && comparison.differing <= tolerance;
    return _result(
      expectation,
      ok,
      comparison.sameSize
          ? '${(comparison.differing * 100).toStringAsFixed(3)}% of pixels differ '
                '(tolerance ${(tolerance * 100).toStringAsFixed(3)}%)'
          : 'size ${comparison.actualSize}, reference ${comparison.referenceSize}',
    );
  }
}

/// How [actual] differs from [reference]: the share of differing pixels
/// (see [goldenChannelThreshold]) and an image of them (red), when both
/// have the same size.
({
  bool sameSize,
  double differing,
  img.Image? diff,
  String referenceSize,
  String actualSize,
})
compareImages(img.Image reference, img.Image actual) {
  final referenceSize = '${reference.width}x${reference.height}';
  final actualSize = '${actual.width}x${actual.height}';
  if (reference.width != actual.width || reference.height != actual.height) {
    return (
      sameSize: false,
      differing: 1,
      diff: null,
      referenceSize: referenceSize,
      actualSize: actualSize,
    );
  }
  final diff = img.Image(
    width: actual.width,
    height: actual.height,
    numChannels: 4,
  );
  var differing = 0;
  for (var y = 0; y < actual.height; y++) {
    for (var x = 0; x < actual.width; x++) {
      final a = reference.getPixel(x, y);
      final b = actual.getPixel(x, y);
      final delta = [
        (a.r - b.r).abs(),
        (a.g - b.g).abs(),
        (a.b - b.b).abs(),
        (a.a - b.a).abs(),
      ].reduce((left, right) => left > right ? left : right);
      if (delta > goldenChannelThreshold) {
        differing++;
        diff.setPixelRgba(x, y, 255, 0, 0, 255);
      } else {
        // The reference, faded, for context.
        diff.setPixelRgba(x, y, b.r ~/ 4, b.g ~/ 4, b.b ~/ 4, 255);
      }
    }
  }
  return (
    sameSize: true,
    differing: differing / (actual.width * actual.height),
    diff: diff,
    referenceSize: referenceSize,
    actualSize: actualSize,
  );
}

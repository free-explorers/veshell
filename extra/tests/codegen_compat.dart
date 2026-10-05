import 'dart:convert';
import 'dart:io';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final wrapper = File.fromUri(Platform.script.resolve('../build/codegen.dart'));
  final patch = File.fromUri(wrapper.uri.resolve('freezed-dart-3.13.patch'));
  final lock = await File.fromUri(Platform.script.resolve('../../src/shell/pubspec.lock'))
      .readAsString();
  final version = RegExp(
    r'^  freezed:\n[\s\S]*?^    version: "([^"]+)"',
    multiLine: true,
  ).firstMatch(lock)!.group(1)!;
  final temp = await Directory.systemTemp.createTemp('codegen compat ');
  try {
    final shell = Directory('${temp.path}/shell');
    final shared = Directory('${temp.path}/shared cache/freezed');
    final template = File('${shared.path}/lib/src/templates/parameter_template.dart');
    await template.parent.create(recursive: true);
    const originalTemplate = '''  @override
  String toString() {
    var res = ' \$typeDisplayString \$name';
    if (isFinal) {
      res = 'final \$res';
    }
    if (isRequired) {
      res = 'required \$res';
    }
''';
    await template.writeAsString(originalTemplate);
    await File('${shared.path}/pubspec.yaml').writeAsString('name: freezed\nversion: $version\n');
    await Link('${shared.path}/linked.txt').create(template.path);
    final runner = File('${temp.path}/fake runner/bin/build_runner.dart');
    await runner.parent.create(recursive: true);
    await runner.writeAsString(r'''
import 'dart:convert';
import 'dart:io';
void main(List<String> args) {
  if (args.join(' ') != 'build --delete-conflicting-outputs') exit(90);
  final config = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync());
  final expected = jsonDecode(File('expected.json').readAsStringSync());
  final freezed = (config['packages'] as List).singleWhere((p) => p['name'] == 'freezed');
  final root = Uri.parse(freezed['rootUri']);
  if (!root.toFilePath().endsWith('/build/codegen/freezed/')) exit(91);
  final source = File.fromUri(root.resolve('lib/src/templates/parameter_template.dart'));
  if (source.readAsStringSync().contains('if (isFinal)')) exit(92);
  freezed['rootUri'] = expected['packages'][0]['rootUri'];
  if (jsonEncode(config) != jsonEncode(expected)) exit(93);
  if (File('expect-invalidated').existsSync() &&
      File('.dart_tool/build/entrypoint/stale').existsSync()) exit(94);
  if (!File('.dart_tool/build/asset_graph.json').existsSync()) exit(95);
  File('ran').writeAsStringSync('yes');
  if (File('fail').existsSync()) exit(17);
}
''');
    final configFile = File('${shell.path}/.dart_tool/package_config.json');
    await configFile.parent.create(recursive: true);
    await File('${shell.path}/pubspec.lock').writeAsString(lock);
    final Map<String, dynamic> config = {
      'configVersion': 2,
      'packages': [
        {
          'name': 'freezed',
          'rootUri': shared.uri.toString(),
          'packageUri': 'lib/',
          'languageVersion': '3.8',
          'extra': 42,
        },
        {
          'name': 'build_runner',
          'rootUri': runner.parent.parent.uri.toString(),
          'packageUri': 'lib/',
        },
      ],
      'generator': 'fixture',
      'unknownField': {'keep': true},
    };
    var originalConfig = '${const JsonEncoder.withIndent('  ').convert(config)}\n';
    await configFile.writeAsString(originalConfig);
    await File('${shell.path}/expected.json').writeAsString(jsonEncode(config));
    final stale = File('${shell.path}/.dart_tool/build/entrypoint/stale');
    final graph = File('${shell.path}/.dart_tool/build/asset_graph.json');
    await stale.parent.create(recursive: true);
    await stale.writeAsString('unpatched');
    await graph.writeAsString('keep');
    final invalidate = File('${shell.path}/expect-invalidated');
    await invalidate.writeAsString('yes');
    Future<void> invoke(int expectedCode) async {
      final result = await Process.run(Platform.resolvedExecutable, [
        wrapper.path,
        'build',
        '--delete-conflicting-outputs',
      ], workingDirectory: shell.path);
      check(
        result.exitCode == expectedCode,
        'exit ${result.exitCode}, expected $expectedCode:\n${result.stdout}${result.stderr}',
      );
      check(await configFile.readAsString() == originalConfig, 'config not restored byte-for-byte');
      check(await template.readAsString() == originalTemplate, 'shared cache changed');
      check(await graph.readAsString() == 'keep', 'asset graph changed');
    }

    await invoke(0);
    check(await File('${shell.path}/ran').exists(), 'runner never ran');
    check(
      await FileSystemEntity.type(
            '${shell.path}/build/codegen/freezed/linked.txt',
            followLinks: false,
          ) ==
          FileSystemEntityType.file,
      'staged file is still a link',
    );
    await invalidate.delete();
    await stale.parent.create(recursive: true);
    await stale.writeAsString('patched');
    await File('${shell.path}/fail').writeAsString('yes');
    await invoke(17);
    check(await stale.exists(), 'unchanged identity invalidated entrypoint');
    await File('${shell.path}/fail').delete();
    // Changing patch input, without changing its effect, must invalidate.
    final localWrapper = await wrapper.copy('${temp.path}/codegen.dart');
    await patch.copy('${temp.path}/freezed-dart-3.13.patch');
    await File('${temp.path}/freezed-dart-3.13.patch')
        .writeAsString('${await patch.readAsString()}\n');
    await invalidate.writeAsString('yes');
    final changed = await Process.run(Platform.resolvedExecutable, [
      localWrapper.path,
      'build',
      '--delete-conflicting-outputs',
    ], workingDirectory: shell.path);
    check(changed.exitCode == 0, 'patch change failed: ${changed.stderr}');
    check(!await stale.exists(), 'patch change left stale entrypoint');
    // Relative URI with encoded spaces; source identity changes as well.
    config['packages']![0]['rootUri'] = '../../shared%20cache/freezed/';
    originalConfig = '${jsonEncode(config)}\n';
    await configFile.writeAsString(originalConfig);
    await File('${shell.path}/expected.json').writeAsString(jsonEncode(config));
    await invoke(0);
    final other = Directory('${temp.path}/other source');
    await Directory('${other.path}/lib/src/templates').create(recursive: true);
    await template.copy('${other.path}/lib/src/templates/parameter_template.dart');
    await File('${shared.path}/pubspec.yaml').copy('${other.path}/pubspec.yaml');
    config['packages'][0]['rootUri'] = other.uri.toString();
    originalConfig = '${jsonEncode(config)}\n';
    await configFile.writeAsString(originalConfig);
    await File('${shell.path}/expected.json').writeAsString(jsonEncode(config));
    await stale.parent.create(recursive: true);
    await stale.writeAsString('previous source');
    await invoke(0);
    check(!await stale.exists(), 'source identity change left stale entrypoint');
    config['packages'][0]['rootUri'] = shared.uri.toString();
    originalConfig = '${jsonEncode(config)}\n';
    await configFile.writeAsString(originalConfig);
    await File('${shell.path}/expected.json').writeAsString(jsonEncode(config));
    // A matching, already patched source is accepted, never reverse-patched.
    await template.writeAsString(
      originalTemplate.replaceFirst("    if (isFinal) {\n      res = 'final \$res';\n    }\n", ''),
    );
    await File('${shell.path}/build/codegen/freezed.identity').delete();
    final patched = await Process.run(Platform.resolvedExecutable, [
      wrapper.path,
      'build',
      '--delete-conflicting-outputs',
    ], workingDirectory: shell.path);
    check(patched.exitCode == 0, 'already patched source rejected: ${patched.stderr}');
    check(
      !await template.readAsString().then((s) => s.contains('if (isFinal)')),
      'patched shared source changed',
    );
    await template.writeAsString('unsupported template\n');
    await File('${shell.path}/build/codegen/freezed.identity').delete();
    final unsupported = await Process.run(Platform.resolvedExecutable, [
      wrapper.path,
      'build',
    ], workingDirectory: shell.path);
    check(
      unsupported.exitCode != 0 &&
          unsupported.stderr.toString().contains('Unsupported Freezed source'),
      'unsupported source not rejected clearly',
    );
    check(await configFile.readAsString() == originalConfig, 'error changed config');
    await File('${shared.path}/pubspec.yaml').writeAsString('version: 0.0.0\n');
    final mismatch = await Process.run(Platform.resolvedExecutable, [
      wrapper.path,
      'build',
    ], workingDirectory: shell.path);
    check(
      mismatch.exitCode != 0 && mismatch.stderr.toString().contains('does not match pubspec.lock'),
      'version mismatch accepted',
    );
    stdout.writeln('codegen compatibility fixtures passed');
  } finally {
    await temp.delete(recursive: true);
  }
}

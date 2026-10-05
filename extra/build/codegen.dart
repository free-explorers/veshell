import 'dart:convert';
import 'dart:io';

// Run from src/shell with the project SDK. Do not run pub get concurrently:
// build_runner needs the temporary package config until its process exits.
Future<void> main(List<String> args) async {
  try {
    await run(args);
  } catch (error) {
    stderr.writeln('codegen: $error');
    exitCode = 1;
  }
}

Future<void> run(List<String> args) async {
  final configFile = File('.dart_tool/package_config.json').absolute;
  final original = await configFile.readAsBytes();
  final config = jsonDecode(utf8.decode(original)) as Map<String, dynamic>;
  final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
  final freezed = packages.singleWhere((p) => p['name'] == 'freezed');
  final runner = packages.singleWhere((p) => p['name'] == 'build_runner');
  final source = Directory.fromUri(configFile.uri.resolve(freezed['rootUri'] as String));
  final runnerFile = configFile.uri
      .resolve(runner['rootUri'] as String)
      .resolve('bin/build_runner.dart');
  final lock = await File('pubspec.lock').readAsString();
  final identity = RegExp(
    r'^  freezed:\r?\n(?:[ \t].*\r?\n)*?(?=^  \S|^\S|$(?![\s\S]))',
    multiLine: true,
  ).firstMatch(lock)?.group(0);
  final version = identity == null
      ? null
      : RegExp(r'^    version: "([^"]+)"\r?$', multiLine: true).firstMatch(identity)?.group(1);
  final sourceVersion = RegExp(
    r'''^version:\s*["']?([^\s"']+)''',
    multiLine: true,
  ).firstMatch(await File.fromUri(source.uri.resolve('pubspec.yaml')).readAsString())?.group(1);
  if (version == null || sourceVersion != version) {
    throw StateError(
      'Freezed source version $sourceVersion does not match pubspec.lock ($version)',
    );
  }
  final patch = File.fromUri(Platform.script.resolve('freezed-dart-3.13.patch'));
  final patchContents = await patch.readAsString();
  final sourcePath = await source.resolveSymbolicLinks();
  final markerContents = jsonEncode([identity, sourcePath, patchContents]);
  final staged = Directory('build/codegen/freezed').absolute;
  final marker = File('build/codegen/freezed.identity');
  final entrypoint = Directory('.dart_tool/build/entrypoint');
  if (!await marker.exists() ||
      await marker.readAsString() != markerContents ||
      !await staged.exists()) {
    // Remove only the compiled generator, not build_runner's asset graph.
    if (await entrypoint.exists()) await entrypoint.delete(recursive: true);
    if (await marker.exists()) await marker.delete();
    if (await staged.exists()) await staged.delete(recursive: true);
    final forward = await Process.run('patch', [
      '--batch',
      '--forward',
      '--fuzz=0',
      '--dry-run',
      '-p1',
      '-d',
      sourcePath,
      '-i',
      patch.path,
    ]);
    if (forward.exitCode != 0) {
      final reverse = await Process.run('patch', [
        '--batch',
        '--reverse',
        '--fuzz=0',
        '--dry-run',
        '-p1',
        '-d',
        sourcePath,
        '-i',
        patch.path,
      ]);
      if (reverse.exitCode != 0) {
        throw StateError(
          'Unsupported Freezed source: patch does not apply in either direction.\n${forward.stdout}${forward.stderr}',
        );
      }
    }
    await staged.create(recursive: true);
    // Following links and copying files gives the private tree no cache links.
    await for (final entity in Directory(sourcePath).list(recursive: true, followLinks: true)) {
      final target = '${staged.path}/${entity.path.substring(sourcePath.length + 1)}';
      if (entity is Directory) {
        await Directory(target).create(recursive: true);
      } else if (entity is File) {
        await File(target).parent.create(recursive: true);
        await entity.copy(target);
      } else {
        throw StateError('Unsupported Freezed source entry: ${entity.path}');
      }
    }
    if (forward.exitCode == 0) {
      final result = await Process.run('patch', [
        '--batch',
        '--forward',
        '--fuzz=0',
        '-p1',
        '-d',
        staged.path,
        '-i',
        patch.path,
      ]);
      if (result.exitCode != 0) {
        throw StateError('Freezed patch failed:\n${result.stdout}${result.stderr}');
      }
    }
    await marker.writeAsString(markerContents);
  }
  freezed['rootUri'] = staged.uri.toString();
  try {
    await configFile.writeAsString(jsonEncode(config));
    final process = await Process.start(Platform.resolvedExecutable, [
      '--packages=${configFile.path}',
      runnerFile.toFilePath(),
      ...args,
    ], mode: ProcessStartMode.inheritStdio);
    exitCode = await process.exitCode;
  } finally {
    await configFile.writeAsBytes(original);
  }
}

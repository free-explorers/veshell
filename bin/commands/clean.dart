import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

class CleanCommand extends Command<int> {
  CleanCommand({required this.logger});
  final Logger logger;
  @override
  final name = 'clean';
  @override
  final description = 'Clean the project and restore it to a fresh state';

  @override
  Future<int> run() async {
    final dirsToDelete = [
      Directory('build'),
      Directory('shell/build'),
      Directory('embedder/target'),
      Directory('shell/.dart_tool'),
    ];
    for (final dir in dirsToDelete) {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }

    final dir = Directory('shell');
    final files = dir.listSync(recursive: true);
    for (final file in files) {
      if (file is File &&
          (file.path.endsWith('.g.dart') ||
              file.path.endsWith('.freezed.dart'))) {
        file.deleteSync();
      }
    }

    return ExitCode.success.code;
  }
}

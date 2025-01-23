import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'config_directory.g.dart';

@riverpod
Directory configDirectory(Ref ref) {
  return Directory(
    Platform.environment['VESHELL_CONFIG_DIR'] ??
        path.join(
          Platform.environment['XDG_CONFIG_HOME'] ??
              '${Platform.environment['HOME']!}/.config',
          'veshell/settings',
        ),
  );
}

import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'config_directory.g.dart';

@riverpod
Directory configDirectory(Ref ref) {
  return Directory(
    Platform.environment['VESHELL_CONFIG_DIR']!,
  );
}

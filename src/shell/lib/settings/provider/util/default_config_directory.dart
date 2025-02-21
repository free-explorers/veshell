import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'default_config_directory.g.dart';

@riverpod
Directory defaultConfigDirectory(Ref ref) {
  return Directory(
    Platform.environment['VESHELL_DEFAULT_CONFIG_DIR']!,
  );
}

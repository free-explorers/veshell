import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'default_config_directory.g.dart';

@Riverpod(keepAlive: true)
Directory defaultConfigDirectory(Ref ref) {
  return Directory(Platform.environment['VESHELL_DEFAULT_CONFIG_DIR']!);
}

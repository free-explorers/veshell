import 'dart:convert';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/default_config_directory.dart';

part 'default_settings_json.g.dart';

@riverpod
class DefaultSettingsJson extends _$DefaultSettingsJson {
  @override
  Map<String, dynamic> build() {
    final defaultConfigDirectory = ref.watch(defaultConfigDirectoryProvider);

    final defaultSettingsJson = jsonDecode(
      File('${defaultConfigDirectory.path}/settings.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    return defaultSettingsJson;
  }
}

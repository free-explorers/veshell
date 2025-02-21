import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/configured_settings_json.dart';
import 'package:shell/settings/provider/util/default_settings_json.dart';

part 'merged_settings_json.g.dart';

@riverpod
class MergedSettingsJson extends _$MergedSettingsJson {
  @override
  Map<String, dynamic> build() {
    final defaultSettingsJson = ref.watch(defaultSettingsJsonProvider);

    final configuredSettingsJson = ref.watch(configuredSettingsJsonProvider);

    final mergedSettingsJson = {
      ...jsonDecode(jsonEncode(defaultSettingsJson))
          as Map<String, dynamic>, // deep copy
    };
    void recursiveOverride(
      Map<String, dynamic> target,
      Map<String, dynamic> source,
    ) {
      source.forEach((key, value) {
        if (target.containsKey(key) &&
            target[key] is Map<String, dynamic> &&
            value is Map<String, dynamic>) {
          recursiveOverride(target[key] as Map<String, dynamic>, value);
        } else {
          target[key] = value;
        }
      });
    }

    recursiveOverride(mergedSettingsJson, configuredSettingsJson);
    return mergedSettingsJson;
  }
}

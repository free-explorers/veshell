import 'dart:ui';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/json_value_by_path.dart';
import 'package:shell/settings/provider/setting_property_by_path.dart';

part 'theme_state.g.dart';

@riverpod
Color themeColor(Ref ref) {
  const path = 'theme.color';
  const fallback = Color(0xFF434C5E);

  final property = ref.watch(settingPropertyByPathProvider(path));
  final jsonValue = ref.watch(jsonValueByPathProvider(path));
  if (property == null || jsonValue == null) {
    return fallback;
  }
  try {
    return property.castValue(jsonValue) as Color;
  } on Exception catch (e) {
    print('Failed to parse theme color: $e');
    return fallback;
  }
}

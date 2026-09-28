import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/settings/model/setting_definition.dart';

part 'setting_group.freezed.dart';

@freezed
abstract class SettingGroup with _$SettingGroup implements SettingDefinition {
  const factory SettingGroup({
    required String name,
    required String? description,
    required Map<String, SettingDefinition> children,
    IconData? icon,
  }) = _SettingGroup;
  const SettingGroup._();
}

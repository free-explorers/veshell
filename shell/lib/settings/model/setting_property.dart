import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/settings/model/setting_definition.dart';

part 'setting_property.freezed.dart';

@freezed
class SettingProperty<T>
    with _$SettingProperty<T>
    implements SettingDefinition {
  const factory SettingProperty({
    required String name,
    required String description,
    JsonConverter<T, String>? converter,
  }) = _SettingProperty;
  const SettingProperty._();

  T castValue(String val) =>
      converter != null ? converter!.fromJson(val) : val as T;

  String serializeValue(T val) =>
      converter != null ? converter!.toJson(val) : val as String;
}

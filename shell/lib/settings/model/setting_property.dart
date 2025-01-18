import 'package:freezed_annotation/freezed_annotation.dart';

part 'setting_property.freezed.dart';

@freezed
class SettingProperty<T> with _$SettingProperty {
  const factory SettingProperty({
    required String name,
    required String description,
    JsonConverter<T, String>? converter,
  }) = _SettingProperty;
  const SettingProperty._();

  T castValue(String val) =>
      converter != null ? converter!.fromJson(val) as T : val as T;

  String serializeValue(T val) =>
      converter != null ? converter!.toJson(val) : val as String;
}

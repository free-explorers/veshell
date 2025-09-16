// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_environment_variables.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SetEnvironmentVariablesMessage _$SetEnvironmentVariablesMessageFromJson(
  Map json,
) => _SetEnvironmentVariablesMessage(
  environmentVariables: IMap<String, String?>.fromJson(
    Map<String, Object?>.from(json['environmentVariables'] as Map),
    (value) => value as String,
    (value) => value as String?,
  ),
);

Map<String, dynamic> _$SetEnvironmentVariablesMessageToJson(
  _SetEnvironmentVariablesMessage instance,
) => <String, dynamic>{
  'environmentVariables': instance.environmentVariables.toJson(
    (value) => value,
    (value) => value,
  ),
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'launch_config.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LaunchConfig _$LaunchConfigFromJson(Map json) => _LaunchConfig(
  command: json['command'] as String,
  arguments:
      (json['arguments'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  useDedicatedGpu: json['useDedicatedGpu'] as bool? ?? false,
);

Map<String, dynamic> _$LaunchConfigToJson(_LaunchConfig instance) =>
    <String, dynamic>{
      'command': instance.command,
      'arguments': instance.arguments,
      'useDedicatedGpu': instance.useDedicatedGpu,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_configuration.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ScreenConfiguration _$ScreenConfigurationFromJson(Map json) =>
    _ScreenConfiguration(
      flex: (json['flex'] as num).toInt(),
      screenId: json['screenId'] as String,
      primaryForMonitor: json['primaryForMonitor'] as String?,
    );

Map<String, dynamic> _$ScreenConfigurationToJson(
  _ScreenConfiguration instance,
) => <String, dynamic>{
  'flex': instance.flex,
  'screenId': instance.screenId,
  'primaryForMonitor': instance.primaryForMonitor,
};

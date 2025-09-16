// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_configuration.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MonitorConfiguration _$MonitorConfigurationFromJson(Map json) =>
    _MonitorConfiguration(
      screenList: IList<ScreenConfiguration>.fromJson(
        json['screenList'],
        (value) => ScreenConfiguration.fromJson(
          Map<String, dynamic>.from(value as Map),
        ),
      ),
      displayMode: $enumDecode(_$ScreenDisplayModeEnumMap, json['displayMode']),
    );

Map<String, dynamic> _$MonitorConfigurationToJson(
  _MonitorConfiguration instance,
) => <String, dynamic>{
  'screenList': instance.screenList.toJson((value) => value.toJson()),
  'displayMode': _$ScreenDisplayModeEnumMap[instance.displayMode]!,
};

const _$ScreenDisplayModeEnumMap = {
  ScreenDisplayMode.splitHorizontal: 'splitHorizontal',
  ScreenDisplayMode.splitVertical: 'splitVertical',
};

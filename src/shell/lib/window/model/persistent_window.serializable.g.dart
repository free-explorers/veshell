// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'persistent_window.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PersistentWindow _$PersistentWindowFromJson(Map json) => _PersistentWindow(
  windowId: PersistentWindowId.fromJson(
    Map<String, dynamic>.from(json['windowId'] as Map),
  ),
  properties: WindowProperties.fromJson(
    Map<String, dynamic>.from(json['properties'] as Map),
  ),
  metaWindowId: json['metaWindowId'] as String?,
  isWaitingForSurface: json['isWaitingForSurface'] as bool? ?? false,
  displayMode:
      $enumDecodeNullable(_$DisplayModeEnumMap, json['displayMode']) ??
      DisplayMode.maximized,
  customExec: json['customExec'] as String?,
  pid: (json['pid'] as num?)?.toInt(),
);

Map<String, dynamic> _$PersistentWindowToJson(_PersistentWindow instance) =>
    <String, dynamic>{
      'windowId': instance.windowId.toJson(),
      'properties': instance.properties.toJson(),
      'metaWindowId': instance.metaWindowId,
      'isWaitingForSurface': instance.isWaitingForSurface,
      'displayMode': _$DisplayModeEnumMap[instance.displayMode]!,
      'customExec': instance.customExec,
      'pid': instance.pid,
    };

const _$DisplayModeEnumMap = {
  DisplayMode.maximized: 'maximized',
  DisplayMode.fullscreen: 'fullscreen',
  DisplayMode.game: 'game',
  DisplayMode.floating: 'floating',
};

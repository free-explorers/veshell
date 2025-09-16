// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_window_patches.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateAppId _$UpdateAppIdFromJson(Map json) => UpdateAppId(
  id: json['id'] as String,
  value: json['value'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UpdateAppIdToJson(UpdateAppId instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'type': instance.$type,
    };

UpdateParent _$UpdateParentFromJson(Map json) => UpdateParent(
  id: json['id'] as String,
  value: json['value'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UpdateParentToJson(UpdateParent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'type': instance.$type,
    };

UpdateTitle _$UpdateTitleFromJson(Map json) => UpdateTitle(
  id: json['id'] as String,
  value: json['value'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UpdateTitleToJson(UpdateTitle instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'type': instance.$type,
    };

UpdatePid _$UpdatePidFromJson(Map json) => UpdatePid(
  id: json['id'] as String,
  value: (json['value'] as num).toInt(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UpdatePidToJson(UpdatePid instance) => <String, dynamic>{
  'id': instance.id,
  'value': instance.value,
  'type': instance.$type,
};

UpdateWindowClass _$UpdateWindowClassFromJson(Map json) => UpdateWindowClass(
  id: json['id'] as String,
  value: json['value'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UpdateWindowClassToJson(UpdateWindowClass instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'type': instance.$type,
    };

UpdateStartupId _$UpdateStartupIdFromJson(Map json) => UpdateStartupId(
  id: json['id'] as String,
  value: json['value'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UpdateStartupIdToJson(UpdateStartupId instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'type': instance.$type,
    };

UpdateDisplayMode _$UpdateDisplayModeFromJson(Map json) => UpdateDisplayMode(
  id: json['id'] as String,
  value: $enumDecodeNullable(_$MetaWindowDisplayModeEnumMap, json['value']),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UpdateDisplayModeToJson(UpdateDisplayMode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': _$MetaWindowDisplayModeEnumMap[instance.value],
      'type': instance.$type,
    };

const _$MetaWindowDisplayModeEnumMap = {
  MetaWindowDisplayMode.maximized: 'maximized',
  MetaWindowDisplayMode.fullscreen: 'fullscreen',
  MetaWindowDisplayMode.floating: 'floating',
};

UpdateMapped _$UpdateMappedFromJson(Map json) => UpdateMapped(
  id: json['id'] as String,
  value: json['value'] as bool,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UpdateMappedToJson(UpdateMapped instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'type': instance.$type,
    };

UpdateGeometry _$UpdateGeometryFromJson(Map json) => UpdateGeometry(
  id: json['id'] as String,
  value: _$JsonConverterFromJson<Map<dynamic, dynamic>, Rect>(
    json['value'],
    const RectConverter().fromJson,
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UpdateGeometryToJson(UpdateGeometry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': _$JsonConverterToJson<Map<dynamic, dynamic>, Rect>(
        instance.value,
        const RectConverter().toJson,
      ),
      'type': instance.$type,
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

UpdateNeedDecoration _$UpdateNeedDecorationFromJson(Map json) =>
    UpdateNeedDecoration(
      id: json['id'] as String,
      value: json['value'] as bool,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$UpdateNeedDecorationToJson(
  UpdateNeedDecoration instance,
) => <String, dynamic>{
  'id': instance.id,
  'value': instance.value,
  'type': instance.$type,
};

UpdateGameModeActivated _$UpdateGameModeActivatedFromJson(Map json) =>
    UpdateGameModeActivated(
      id: json['id'] as String,
      value: json['value'] as bool,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$UpdateGameModeActivatedToJson(
  UpdateGameModeActivated instance,
) => <String, dynamic>{
  'id': instance.id,
  'value': instance.value,
  'type': instance.$type,
};

UpdateCurrentOutput _$UpdateCurrentOutputFromJson(Map json) =>
    UpdateCurrentOutput(
      id: json['id'] as String,
      value: json['value'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$UpdateCurrentOutputToJson(
  UpdateCurrentOutput instance,
) => <String, dynamic>{
  'id': instance.id,
  'value': instance.value,
  'type': instance.$type,
};

UpdateScaleRatio _$UpdateScaleRatioFromJson(Map json) => UpdateScaleRatio(
  id: json['id'] as String,
  value: (json['value'] as num).toDouble(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UpdateScaleRatioToJson(UpdateScaleRatio instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'type': instance.$type,
    };

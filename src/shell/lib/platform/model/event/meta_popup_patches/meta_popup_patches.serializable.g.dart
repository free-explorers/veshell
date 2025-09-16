// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_popup_patches.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdatePosition _$UpdatePositionFromJson(Map json) => UpdatePosition(
  id: json['id'] as String,
  value: const OffsetConverter().fromJson(json['value'] as Map),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UpdatePositionToJson(UpdatePosition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': const OffsetConverter().toJson(instance.value),
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

UpdateGeometry _$UpdateGeometryFromJson(Map json) => UpdateGeometry(
  id: json['id'] as String,
  value: const RectConverter().fromJson(json['value'] as Map),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UpdateGeometryToJson(UpdateGeometry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': const RectConverter().toJson(instance.value),
      'type': instance.$type,
    };

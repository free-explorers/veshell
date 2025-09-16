// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_popup.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MetaPopup _$MetaPopupFromJson(Map json) => _MetaPopup(
  id: json['id'] as String,
  parent: json['parent'] as String,
  surfaceId: (json['surfaceId'] as num).toInt(),
  scaleRatio: (json['scaleRatio'] as num).toDouble(),
  position: const OffsetConverter().fromJson(json['position'] as Map),
  geometry: _$JsonConverterFromJson<Map<dynamic, dynamic>, Rect>(
    json['geometry'],
    const RectConverter().fromJson,
  ),
);

Map<String, dynamic> _$MetaPopupToJson(_MetaPopup instance) =>
    <String, dynamic>{
      'id': instance.id,
      'parent': instance.parent,
      'surfaceId': instance.surfaceId,
      'scaleRatio': instance.scaleRatio,
      'position': const OffsetConverter().toJson(instance.position),
      'geometry': _$JsonConverterToJson<Map<dynamic, dynamic>, Rect>(
        instance.geometry,
        const RectConverter().toJson,
      ),
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

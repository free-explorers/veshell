// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_popup_created.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MetaPopupCreatedMessage _$MetaPopupCreatedMessageFromJson(Map json) =>
    _MetaPopupCreatedMessage(
      id: json['id'] as String,
      parent: json['parent'] as String,
      surfaceId: (json['surfaceId'] as num).toInt(),
      scaleRatio: (json['scaleRatio'] as num).toDouble(),
      position: const OffsetConverter().fromJson(json['position'] as Map),
      currentOutput: json['currentOutput'] as String?,
    );

Map<String, dynamic> _$MetaPopupCreatedMessageToJson(
  _MetaPopupCreatedMessage instance,
) => <String, dynamic>{
  'id': instance.id,
  'parent': instance.parent,
  'surfaceId': instance.surfaceId,
  'scaleRatio': instance.scaleRatio,
  'position': const OffsetConverter().toJson(instance.position),
  'currentOutput': instance.currentOutput,
};

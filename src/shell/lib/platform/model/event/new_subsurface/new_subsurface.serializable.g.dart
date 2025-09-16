// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'new_subsurface.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NewSubsurfaceMessage _$NewSubsurfaceMessageFromJson(Map json) =>
    _NewSubsurfaceMessage(
      surfaceId: (json['surfaceId'] as num).toInt(),
      parent: (json['parent'] as num).toInt(),
    );

Map<String, dynamic> _$NewSubsurfaceMessageToJson(
  _NewSubsurfaceMessage instance,
) => <String, dynamic>{
  'surfaceId': instance.surfaceId,
  'parent': instance.parent,
};

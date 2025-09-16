// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commit_surface.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CommitSurfaceMessage _$CommitSurfaceMessageFromJson(Map json) =>
    _CommitSurfaceMessage(
      surfaceId: (json['surfaceId'] as num).toInt(),
      role: json['role'] == null
          ? null
          : SurfaceRoleMessage.fromJson(
              Map<String, dynamic>.from(json['role'] as Map),
            ),
      textureId: (json['textureId'] as num).toInt(),
      scale: (json['scale'] as num).toInt(),
      inputRegion: const RectConverter().fromJson(json['inputRegion'] as Map),
      subsurfacesBelow: IList<int>.fromJson(
        json['subsurfacesBelow'],
        (value) => (value as num).toInt(),
      ),
      subsurfacesAbove: IList<int>.fromJson(
        json['subsurfacesAbove'],
        (value) => (value as num).toInt(),
      ),
      bufferDelta: _$JsonConverterFromJson<Map<dynamic, dynamic>, Offset>(
        json['bufferDelta'],
        const OffsetConverter().fromJson,
      ),
      bufferSize: _$JsonConverterFromJson<Map<dynamic, dynamic>, Size>(
        json['bufferSize'],
        const SizeConverter().fromJson,
      ),
    );

Map<String, dynamic> _$CommitSurfaceMessageToJson(
  _CommitSurfaceMessage instance,
) => <String, dynamic>{
  'surfaceId': instance.surfaceId,
  'role': instance.role?.toJson(),
  'textureId': instance.textureId,
  'scale': instance.scale,
  'inputRegion': const RectConverter().toJson(instance.inputRegion),
  'subsurfacesBelow': instance.subsurfacesBelow.toJson((value) => value),
  'subsurfacesAbove': instance.subsurfacesAbove.toJson((value) => value),
  'bufferDelta': _$JsonConverterToJson<Map<dynamic, dynamic>, Offset>(
    instance.bufferDelta,
    const OffsetConverter().toJson,
  ),
  'bufferSize': _$JsonConverterToJson<Map<dynamic, dynamic>, Size>(
    instance.bufferSize,
    const SizeConverter().toJson,
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

SubsurfaceRoleMessage _$SubsurfaceRoleMessageFromJson(Map json) =>
    SubsurfaceRoleMessage(
      parent: (json['parent'] as num).toInt(),
      position: const OffsetConverter().fromJson(json['position'] as Map),
    );

Map<String, dynamic> _$SubsurfaceRoleMessageToJson(
  SubsurfaceRoleMessage instance,
) => <String, dynamic>{
  'parent': instance.parent,
  'position': const OffsetConverter().toJson(instance.position),
};

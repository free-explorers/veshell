// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pointer_focus.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PointerFocus _$PointerFocusFromJson(Map json) => _PointerFocus(
  surfaceId: (json['surfaceId'] as num).toInt(),
  globalOffset: const OffsetConverter().fromJson(json['globalOffset'] as Map),
);

Map<String, dynamic> _$PointerFocusToJson(_PointerFocus instance) =>
    <String, dynamic>{
      'surfaceId': instance.surfaceId,
      'globalOffset': const OffsetConverter().toJson(instance.globalOffset),
    };

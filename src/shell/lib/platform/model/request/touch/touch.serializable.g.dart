// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'touch.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TouchDownMessage _$TouchDownMessageFromJson(Map json) => _TouchDownMessage(
  surfaceId: (json['surfaceId'] as num).toInt(),
  touchId: (json['touchId'] as num).toInt(),
);

Map<String, dynamic> _$TouchDownMessageToJson(_TouchDownMessage instance) =>
    <String, dynamic>{
      'surfaceId': instance.surfaceId,
      'touchId': instance.touchId,
    };

_TouchMotionMessage _$TouchMotionMessageFromJson(Map json) =>
    _TouchMotionMessage(touchId: (json['touchId'] as num).toInt());

Map<String, dynamic> _$TouchMotionMessageToJson(_TouchMotionMessage instance) =>
    <String, dynamic>{'touchId': instance.touchId};

_TouchIdMessage _$TouchIdMessageFromJson(Map json) =>
    _TouchIdMessage(touchId: (json['touchId'] as num).toInt());

Map<String, dynamic> _$TouchIdMessageToJson(_TouchIdMessage instance) =>
    <String, dynamic>{'touchId': instance.touchId};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gesture_swipe_update.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GestureSwipeUpdateMessage _$GestureSwipeUpdateMessageFromJson(Map json) =>
    _GestureSwipeUpdateMessage(
      time: (json['time'] as num).toInt(),
      fingers: (json['fingers'] as num).toInt(),
      deltaX: (json['deltaX'] as num).toDouble(),
      deltaY: (json['deltaY'] as num).toDouble(),
    );

Map<String, dynamic> _$GestureSwipeUpdateMessageToJson(
  _GestureSwipeUpdateMessage instance,
) => <String, dynamic>{
  'time': instance.time,
  'fingers': instance.fingers,
  'deltaX': instance.deltaX,
  'deltaY': instance.deltaY,
};

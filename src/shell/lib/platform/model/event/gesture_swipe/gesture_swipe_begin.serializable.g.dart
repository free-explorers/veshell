// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gesture_swipe_begin.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GestureSwipeBeginMessage _$GestureSwipeBeginMessageFromJson(Map json) =>
    _GestureSwipeBeginMessage(
      time: (json['time'] as num).toInt(),
      fingers: (json['fingers'] as num).toInt(),
    );

Map<String, dynamic> _$GestureSwipeBeginMessageToJson(
  _GestureSwipeBeginMessage instance,
) => <String, dynamic>{'time': instance.time, 'fingers': instance.fingers};

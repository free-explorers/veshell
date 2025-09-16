// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gesture_swipe_end.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GestureSwipeEndMessage _$GestureSwipeEndMessageFromJson(Map json) =>
    _GestureSwipeEndMessage(
      time: (json['time'] as num).toInt(),
      fingers: (json['fingers'] as num).toInt(),
      cancelled: json['cancelled'] as bool,
    );

Map<String, dynamic> _$GestureSwipeEndMessageToJson(
  _GestureSwipeEndMessage instance,
) => <String, dynamic>{
  'time': instance.time,
  'fingers': instance.fingers,
  'cancelled': instance.cancelled,
};

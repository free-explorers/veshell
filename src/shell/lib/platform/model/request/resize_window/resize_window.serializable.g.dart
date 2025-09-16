// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resize_window.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ResizeWindowMessage _$ResizeWindowMessageFromJson(Map json) =>
    _ResizeWindowMessage(
      metaWindowId: json['metaWindowId'] as String,
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );

Map<String, dynamic> _$ResizeWindowMessageToJson(
  _ResizeWindowMessage instance,
) => <String, dynamic>{
  'metaWindowId': instance.metaWindowId,
  'width': instance.width,
  'height': instance.height,
};

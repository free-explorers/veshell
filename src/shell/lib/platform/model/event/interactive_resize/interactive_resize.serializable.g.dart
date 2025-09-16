// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interactive_resize.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InteractiveResizeMessage _$InteractiveResizeMessageFromJson(Map json) =>
    _InteractiveResizeMessage(
      metaWindowId: json['metaWindowId'] as String,
      edge: const ResizeEdgeConverter().fromJson((json['edge'] as num).toInt()),
    );

Map<String, dynamic> _$InteractiveResizeMessageToJson(
  _InteractiveResizeMessage instance,
) => <String, dynamic>{
  'metaWindowId': instance.metaWindowId,
  'edge': const ResizeEdgeConverter().toJson(instance.edge),
};

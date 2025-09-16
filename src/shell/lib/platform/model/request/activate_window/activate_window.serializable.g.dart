// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activate_window.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ActivateWindowMessage _$ActivateWindowMessageFromJson(Map json) =>
    _ActivateWindowMessage(
      surfaceId: (json['surfaceId'] as num).toInt(),
      activate: json['activate'] as bool,
    );

Map<String, dynamic> _$ActivateWindowMessageToJson(
  _ActivateWindowMessage instance,
) => <String, dynamic>{
  'surfaceId': instance.surfaceId,
  'activate': instance.activate,
};

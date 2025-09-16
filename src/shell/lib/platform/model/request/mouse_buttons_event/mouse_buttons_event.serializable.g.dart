// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mouse_buttons_event.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MouseButtonsEventMessage _$MouseButtonsEventMessageFromJson(Map json) =>
    _MouseButtonsEventMessage(
      surfaceId: (json['surfaceId'] as num).toInt(),
      buttons: IList<Button>.fromJson(
        json['buttons'],
        (value) => Button.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );

Map<String, dynamic> _$MouseButtonsEventMessageToJson(
  _MouseButtonsEventMessage instance,
) => <String, dynamic>{
  'surfaceId': instance.surfaceId,
  'buttons': instance.buttons.toJson((value) => value.toJson()),
};

_Button _$ButtonFromJson(Map json) => _Button(
  button: (json['button'] as num).toInt(),
  isPressed: json['isPressed'] as bool,
);

Map<String, dynamic> _$ButtonToJson(_Button instance) => <String, dynamic>{
  'button': instance.button,
  'isPressed': instance.isPressed,
};

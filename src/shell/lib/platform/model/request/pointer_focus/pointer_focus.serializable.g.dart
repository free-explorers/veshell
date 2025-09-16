// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pointer_focus.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PointerFocusMessage _$PointerFocusMessageFromJson(Map json) =>
    _PointerFocusMessage(
      focus: json['focus'] == null
          ? null
          : PointerFocus.fromJson(
              Map<String, dynamic>.from(json['focus'] as Map),
            ),
    );

Map<String, dynamic> _$PointerFocusMessageToJson(
  _PointerFocusMessage instance,
) => <String, dynamic>{'focus': instance.focus?.toJson()};

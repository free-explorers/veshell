// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_manager_state.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ScreenManagerState _$ScreenManagerStateFromJson(Map json) =>
    _ScreenManagerState(
      screenIds: ISet<String>.fromJson(
        json['screenIds'],
        (value) => value as String,
      ),
    );

Map<String, dynamic> _$ScreenManagerStateToJson(_ScreenManagerState instance) =>
    <String, dynamic>{'screenIds': instance.screenIds.toJson((value) => value)};

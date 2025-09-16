// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_manager_state.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WindowManagerState _$WindowManagerStateFromJson(Map json) =>
    _WindowManagerState(
      windows: ISet<WindowId>.fromJson(
        json['windows'],
        (value) => WindowId.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );

Map<String, dynamic> _$WindowManagerStateToJson(_WindowManagerState instance) =>
    <String, dynamic>{
      'windows': instance.windows.toJson((value) => value.toJson()),
    };

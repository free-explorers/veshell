// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Screen _$ScreenFromJson(Map json) => _Screen(
  screenId: json['screenId'] as String,
  workspaceList: IList<String>.fromJson(
    json['workspaceList'],
    (value) => value as String,
  ),
  selectedIndex: (json['selectedIndex'] as num).toInt(),
  label: json['label'] as String?,
);

Map<String, dynamic> _$ScreenToJson(_Screen instance) => <String, dynamic>{
  'screenId': instance.screenId,
  'workspaceList': instance.workspaceList.toJson((value) => value),
  'selectedIndex': instance.selectedIndex,
  'label': instance.label,
};

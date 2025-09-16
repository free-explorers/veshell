// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Workspace _$WorkspaceFromJson(Map json) => _Workspace(
  workspaceId: json['workspaceId'] as String,
  tileableWindowList: IList<PersistentWindowId>.fromJson(
    json['tileableWindowList'],
    (value) =>
        PersistentWindowId.fromJson(Map<String, dynamic>.from(value as Map)),
  ),
  selectedIndex: (json['selectedIndex'] as num).toInt(),
  visibleLength: (json['visibleLength'] as num).toInt(),
  category: $enumDecodeNullable(_$WorkspaceCategoryEnumMap, json['category']),
  forcedCategory: $enumDecodeNullable(
    _$WorkspaceCategoryEnumMap,
    json['forcedCategory'],
  ),
);

Map<String, dynamic> _$WorkspaceToJson(_Workspace instance) =>
    <String, dynamic>{
      'workspaceId': instance.workspaceId,
      'tileableWindowList': instance.tileableWindowList.toJson(
        (value) => value.toJson(),
      ),
      'selectedIndex': instance.selectedIndex,
      'visibleLength': instance.visibleLength,
      'category': _$WorkspaceCategoryEnumMap[instance.category],
      'forcedCategory': _$WorkspaceCategoryEnumMap[instance.forcedCategory],
    };

const _$WorkspaceCategoryEnumMap = {
  WorkspaceCategory.Game: 'Game',
  WorkspaceCategory.Development: 'Development',
  WorkspaceCategory.Video: 'Video',
  WorkspaceCategory.Audio: 'Audio',
  WorkspaceCategory.AudioVideo: 'AudioVideo',
  WorkspaceCategory.Graphics: 'Graphics',
  WorkspaceCategory.Office: 'Office',
  WorkspaceCategory.Science: 'Science',
  WorkspaceCategory.Education: 'Education',
  WorkspaceCategory.FileManager: 'FileManager',
  WorkspaceCategory.InstantMessaging: 'InstantMessaging',
  WorkspaceCategory.Network: 'Network',
  WorkspaceCategory.Settings: 'Settings',
  WorkspaceCategory.System: 'System',
  WorkspaceCategory.Utility: 'Utility',
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_hints.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationHints _$NotificationHintsFromJson(Map json) => _NotificationHints(
  actionIcons: json['actionIcons'] as bool?,
  category: json['category'] as String?,
  desktopEntry: json['desktopEntry'] as String?,
  imageData: (json['imageData'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  imagePath: json['imagePath'] as String?,
  iconData: (json['iconData'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  resident: json['resident'] as bool?,
  soundFile: json['soundFile'] as String?,
  soundName: json['soundName'] as String?,
  suppressSound: json['suppressSound'] as bool?,
  transient: json['transient'] as bool?,
  x: (json['x'] as num?)?.toInt(),
  y: (json['y'] as num?)?.toInt(),
  urgency: (json['urgency'] as num?)?.toInt(),
);

Map<String, dynamic> _$NotificationHintsToJson(_NotificationHints instance) =>
    <String, dynamic>{
      'actionIcons': instance.actionIcons,
      'category': instance.category,
      'desktopEntry': instance.desktopEntry,
      'imageData': instance.imageData,
      'imagePath': instance.imagePath,
      'iconData': instance.iconData,
      'resident': instance.resident,
      'soundFile': instance.soundFile,
      'soundName': instance.soundName,
      'suppressSound': instance.suppressSound,
      'transient': instance.transient,
      'x': instance.x,
      'y': instance.y,
      'urgency': instance.urgency,
    };

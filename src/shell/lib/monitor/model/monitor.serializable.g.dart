// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Monitor _$MonitorFromJson(Map json) => _Monitor(
  name: json['name'] as String,
  description: json['description'] as String,
  physicalProperties: PhysicalProperties.fromJson(
    Map<String, dynamic>.from(json['physicalProperties'] as Map),
  ),
  scale: (json['scale'] as num).toDouble(),
  location: const OffsetIntConverter().fromJson(json['location'] as Map),
  currentMode: json['currentMode'] == null
      ? null
      : Mode.fromJson(Map<String, dynamic>.from(json['currentMode'] as Map)),
  preferredMode: json['preferredMode'] == null
      ? null
      : Mode.fromJson(Map<String, dynamic>.from(json['preferredMode'] as Map)),
  modes: (json['modes'] as List<dynamic>)
      .map((e) => Mode.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  viewId: (json['viewId'] as num).toInt(),
);

Map<String, dynamic> _$MonitorToJson(_Monitor instance) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'physicalProperties': instance.physicalProperties.toJson(),
  'scale': instance.scale,
  'location': const OffsetIntConverter().toJson(instance.location),
  'currentMode': instance.currentMode?.toJson(),
  'preferredMode': instance.preferredMode?.toJson(),
  'modes': instance.modes.map((e) => e.toJson()).toList(),
  'viewId': instance.viewId,
};

_Mode _$ModeFromJson(Map json) => _Mode(
  size: const SizeIntConverter().fromJson(json['size'] as Map),
  refreshRate: (json['refreshRate'] as num).toInt(),
);

Map<String, dynamic> _$ModeToJson(_Mode instance) => <String, dynamic>{
  'size': const SizeIntConverter().toJson(instance.size),
  'refreshRate': instance.refreshRate,
};

_PhysicalProperties _$PhysicalPropertiesFromJson(Map json) =>
    _PhysicalProperties(
      size: const SizeIntConverter().fromJson(json['size'] as Map),
      make: json['make'] as String,
      model: json['model'] as String,
    );

Map<String, dynamic> _$PhysicalPropertiesToJson(_PhysicalProperties instance) =>
    <String, dynamic>{
      'size': const SizeIntConverter().toJson(instance.size),
      'make': instance.make,
      'model': instance.model,
    };

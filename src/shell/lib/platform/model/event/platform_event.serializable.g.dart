// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_event.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NewSurfaceEvent _$NewSurfaceEventFromJson(Map json) => NewSurfaceEvent(
  method: json['method'] as String,
  message: NewSurfaceMessage.fromJson(
    Map<String, dynamic>.from(json['message'] as Map),
  ),
);

Map<String, dynamic> _$NewSurfaceEventToJson(NewSurfaceEvent instance) =>
    <String, dynamic>{
      'method': instance.method,
      'message': instance.message.toJson(),
    };

NewSubsurfaceEvent _$NewSubsurfaceEventFromJson(Map json) => NewSubsurfaceEvent(
  method: json['method'] as String,
  message: NewSubsurfaceMessage.fromJson(
    Map<String, dynamic>.from(json['message'] as Map),
  ),
);

Map<String, dynamic> _$NewSubsurfaceEventToJson(NewSubsurfaceEvent instance) =>
    <String, dynamic>{
      'method': instance.method,
      'message': instance.message.toJson(),
    };

MetaWindowCreatedEvent _$MetaWindowCreatedEventFromJson(Map json) =>
    MetaWindowCreatedEvent(
      method: json['method'] as String,
      message: MetaWindowCreatedMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$MetaWindowCreatedEventToJson(
  MetaWindowCreatedEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

MetaWindowPatchEvent _$MetaWindowPatchEventFromJson(Map json) =>
    MetaWindowPatchEvent(
      method: json['method'] as String,
      message: MetaWindowPatchMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$MetaWindowPatchEventToJson(
  MetaWindowPatchEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

MetaWindowRemovedEvent _$MetaWindowRemovedEventFromJson(Map json) =>
    MetaWindowRemovedEvent(
      method: json['method'] as String,
      message: MetaWindowRemovedMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$MetaWindowRemovedEventToJson(
  MetaWindowRemovedEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

MetaPopupCreatedEvent _$MetaPopupCreatedEventFromJson(Map json) =>
    MetaPopupCreatedEvent(
      method: json['method'] as String,
      message: MetaPopupCreatedMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$MetaPopupCreatedEventToJson(
  MetaPopupCreatedEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

MetaPopupPatchEvent _$MetaPopupPatchEventFromJson(Map json) =>
    MetaPopupPatchEvent(
      method: json['method'] as String,
      message: MetaPopupPatchMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$MetaPopupPatchEventToJson(
  MetaPopupPatchEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

MetaPopupRemovedEvent _$MetaPopupRemovedEventFromJson(Map json) =>
    MetaPopupRemovedEvent(
      method: json['method'] as String,
      message: MetaPopupRemovedMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$MetaPopupRemovedEventToJson(
  MetaPopupRemovedEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

CommitSurfaceEvent _$CommitSurfaceEventFromJson(Map json) => CommitSurfaceEvent(
  method: json['method'] as String,
  message: CommitSurfaceMessage.fromJson(
    Map<String, dynamic>.from(json['message'] as Map),
  ),
);

Map<String, dynamic> _$CommitSurfaceEventToJson(CommitSurfaceEvent instance) =>
    <String, dynamic>{
      'method': instance.method,
      'message': instance.message.toJson(),
    };

DestroySurfaceEvent _$DestroySurfaceEventFromJson(Map json) =>
    DestroySurfaceEvent(
      method: json['method'] as String,
      message: DestroySurfaceMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$DestroySurfaceEventToJson(
  DestroySurfaceEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

DestroySubsurfaceEvent _$DestroySubsurfaceEventFromJson(Map json) =>
    DestroySubsurfaceEvent(
      method: json['method'] as String,
      message: DestroySubsurfaceMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$DestroySubsurfaceEventToJson(
  DestroySubsurfaceEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

InteractiveMoveEvent _$InteractiveMoveEventFromJson(Map json) =>
    InteractiveMoveEvent(
      method: json['method'] as String,
      message: InteractiveMoveMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$InteractiveMoveEventToJson(
  InteractiveMoveEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

InteractiveResizeEvent _$InteractiveResizeEventFromJson(Map json) =>
    InteractiveResizeEvent(
      method: json['method'] as String,
      message: InteractiveResizeMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$InteractiveResizeEventToJson(
  InteractiveResizeEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

MonitorLayoutChangedEvent _$MonitorLayoutChangedEventFromJson(Map json) =>
    MonitorLayoutChangedEvent(
      method: json['method'] as String,
      message: MonitorLayoutChangedMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$MonitorLayoutChangedEventToJson(
  MonitorLayoutChangedEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

SetEnvironmentVariablesEvent _$SetEnvironmentVariablesEventFromJson(Map json) =>
    SetEnvironmentVariablesEvent(
      method: json['method'] as String,
      message: SetEnvironmentVariablesMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$SetEnvironmentVariablesEventToJson(
  SetEnvironmentVariablesEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

GestureSwipeBeginEvent _$GestureSwipeBeginEventFromJson(Map json) =>
    GestureSwipeBeginEvent(
      method: json['method'] as String,
      message: GestureSwipeBeginMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$GestureSwipeBeginEventToJson(
  GestureSwipeBeginEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

GestureSwipeUpdateEvent _$GestureSwipeUpdateEventFromJson(Map json) =>
    GestureSwipeUpdateEvent(
      method: json['method'] as String,
      message: GestureSwipeUpdateMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$GestureSwipeUpdateEventToJson(
  GestureSwipeUpdateEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

GestureSwipeEndEvent _$GestureSwipeEndEventFromJson(Map json) =>
    GestureSwipeEndEvent(
      method: json['method'] as String,
      message: GestureSwipeEndMessage.fromJson(
        Map<String, dynamic>.from(json['message'] as Map),
      ),
    );

Map<String, dynamic> _$GestureSwipeEndEventToJson(
  GestureSwipeEndEvent instance,
) => <String, dynamic>{
  'method': instance.method,
  'message': instance.message.toJson(),
};

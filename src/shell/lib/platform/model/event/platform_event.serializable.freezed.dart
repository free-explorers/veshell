// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'platform_event.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
PlatformEvent _$PlatformEventFromJson(
  Map<String, dynamic> json
) {
        switch (json['method']) {
                  case 'new_surface':
          return NewSurfaceEvent.fromJson(
            json
          );
                case 'new_subsurface':
          return NewSubsurfaceEvent.fromJson(
            json
          );
                case 'meta_window_created':
          return MetaWindowCreatedEvent.fromJson(
            json
          );
                case 'meta_window_patch':
          return MetaWindowPatchEvent.fromJson(
            json
          );
                case 'meta_window_removed':
          return MetaWindowRemovedEvent.fromJson(
            json
          );
                case 'meta_popup_created':
          return MetaPopupCreatedEvent.fromJson(
            json
          );
                case 'meta_popup_patch':
          return MetaPopupPatchEvent.fromJson(
            json
          );
                case 'meta_popup_removed':
          return MetaPopupRemovedEvent.fromJson(
            json
          );
                case 'commit_surface':
          return CommitSurfaceEvent.fromJson(
            json
          );
                case 'destroy_surface':
          return DestroySurfaceEvent.fromJson(
            json
          );
                case 'destroy_subsurface':
          return DestroySubsurfaceEvent.fromJson(
            json
          );
                case 'interactive_move':
          return InteractiveMoveEvent.fromJson(
            json
          );
                case 'interactive_resize':
          return InteractiveResizeEvent.fromJson(
            json
          );
                case 'monitor_layout_changed':
          return MonitorLayoutChangedEvent.fromJson(
            json
          );
                case 'set_environment_variables':
          return SetEnvironmentVariablesEvent.fromJson(
            json
          );
                case 'gesture_swipe_begin':
          return GestureSwipeBeginEvent.fromJson(
            json
          );
                case 'gesture_swipe_update':
          return GestureSwipeUpdateEvent.fromJson(
            json
          );
                case 'gesture_swipe_end':
          return GestureSwipeEndEvent.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'method',
  'PlatformEvent',
  'Invalid union type "${json['method']}"!'
);
        }
      
}

/// @nodoc
mixin _$PlatformEvent {

 String get method; PlatformMessage get message;
/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlatformEventCopyWith<PlatformEvent> get copyWith => _$PlatformEventCopyWithImpl<PlatformEvent>(this as PlatformEvent, _$identity);

  /// Serializes this PlatformEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlatformEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $PlatformEventCopyWith<$Res>  {
  factory $PlatformEventCopyWith(PlatformEvent value, $Res Function(PlatformEvent) _then) = _$PlatformEventCopyWithImpl;
@useResult
$Res call({
 String method
});




}
/// @nodoc
class _$PlatformEventCopyWithImpl<$Res>
    implements $PlatformEventCopyWith<$Res> {
  _$PlatformEventCopyWithImpl(this._self, this._then);

  final PlatformEvent _self;
  final $Res Function(PlatformEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? method = null,}) {
  return _then(_self.copyWith(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PlatformEvent].
extension PlatformEventPatterns on PlatformEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( NewSurfaceEvent value)?  newSurface,TResult Function( NewSubsurfaceEvent value)?  newSubsurface,TResult Function( MetaWindowCreatedEvent value)?  metaWindowCreated,TResult Function( MetaWindowPatchEvent value)?  metaWindowPatch,TResult Function( MetaWindowRemovedEvent value)?  metaWindowRemoved,TResult Function( MetaPopupCreatedEvent value)?  metaPopupCreated,TResult Function( MetaPopupPatchEvent value)?  metaPopupPatch,TResult Function( MetaPopupRemovedEvent value)?  metaPopupRemoved,TResult Function( CommitSurfaceEvent value)?  commitSurface,TResult Function( DestroySurfaceEvent value)?  destroySurface,TResult Function( DestroySubsurfaceEvent value)?  destroySubsurface,TResult Function( InteractiveMoveEvent value)?  interactiveMove,TResult Function( InteractiveResizeEvent value)?  interactiveResize,TResult Function( MonitorLayoutChangedEvent value)?  monitorLayoutChanged,TResult Function( SetEnvironmentVariablesEvent value)?  setEnvironmentVariables,TResult Function( GestureSwipeBeginEvent value)?  gestureSwipeBegin,TResult Function( GestureSwipeUpdateEvent value)?  gestureSwipeUpdate,TResult Function( GestureSwipeEndEvent value)?  gestureSwipeEnd,required TResult orElse(),}){
final _that = this;
switch (_that) {
case NewSurfaceEvent() when newSurface != null:
return newSurface(_that);case NewSubsurfaceEvent() when newSubsurface != null:
return newSubsurface(_that);case MetaWindowCreatedEvent() when metaWindowCreated != null:
return metaWindowCreated(_that);case MetaWindowPatchEvent() when metaWindowPatch != null:
return metaWindowPatch(_that);case MetaWindowRemovedEvent() when metaWindowRemoved != null:
return metaWindowRemoved(_that);case MetaPopupCreatedEvent() when metaPopupCreated != null:
return metaPopupCreated(_that);case MetaPopupPatchEvent() when metaPopupPatch != null:
return metaPopupPatch(_that);case MetaPopupRemovedEvent() when metaPopupRemoved != null:
return metaPopupRemoved(_that);case CommitSurfaceEvent() when commitSurface != null:
return commitSurface(_that);case DestroySurfaceEvent() when destroySurface != null:
return destroySurface(_that);case DestroySubsurfaceEvent() when destroySubsurface != null:
return destroySubsurface(_that);case InteractiveMoveEvent() when interactiveMove != null:
return interactiveMove(_that);case InteractiveResizeEvent() when interactiveResize != null:
return interactiveResize(_that);case MonitorLayoutChangedEvent() when monitorLayoutChanged != null:
return monitorLayoutChanged(_that);case SetEnvironmentVariablesEvent() when setEnvironmentVariables != null:
return setEnvironmentVariables(_that);case GestureSwipeBeginEvent() when gestureSwipeBegin != null:
return gestureSwipeBegin(_that);case GestureSwipeUpdateEvent() when gestureSwipeUpdate != null:
return gestureSwipeUpdate(_that);case GestureSwipeEndEvent() when gestureSwipeEnd != null:
return gestureSwipeEnd(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( NewSurfaceEvent value)  newSurface,required TResult Function( NewSubsurfaceEvent value)  newSubsurface,required TResult Function( MetaWindowCreatedEvent value)  metaWindowCreated,required TResult Function( MetaWindowPatchEvent value)  metaWindowPatch,required TResult Function( MetaWindowRemovedEvent value)  metaWindowRemoved,required TResult Function( MetaPopupCreatedEvent value)  metaPopupCreated,required TResult Function( MetaPopupPatchEvent value)  metaPopupPatch,required TResult Function( MetaPopupRemovedEvent value)  metaPopupRemoved,required TResult Function( CommitSurfaceEvent value)  commitSurface,required TResult Function( DestroySurfaceEvent value)  destroySurface,required TResult Function( DestroySubsurfaceEvent value)  destroySubsurface,required TResult Function( InteractiveMoveEvent value)  interactiveMove,required TResult Function( InteractiveResizeEvent value)  interactiveResize,required TResult Function( MonitorLayoutChangedEvent value)  monitorLayoutChanged,required TResult Function( SetEnvironmentVariablesEvent value)  setEnvironmentVariables,required TResult Function( GestureSwipeBeginEvent value)  gestureSwipeBegin,required TResult Function( GestureSwipeUpdateEvent value)  gestureSwipeUpdate,required TResult Function( GestureSwipeEndEvent value)  gestureSwipeEnd,}){
final _that = this;
switch (_that) {
case NewSurfaceEvent():
return newSurface(_that);case NewSubsurfaceEvent():
return newSubsurface(_that);case MetaWindowCreatedEvent():
return metaWindowCreated(_that);case MetaWindowPatchEvent():
return metaWindowPatch(_that);case MetaWindowRemovedEvent():
return metaWindowRemoved(_that);case MetaPopupCreatedEvent():
return metaPopupCreated(_that);case MetaPopupPatchEvent():
return metaPopupPatch(_that);case MetaPopupRemovedEvent():
return metaPopupRemoved(_that);case CommitSurfaceEvent():
return commitSurface(_that);case DestroySurfaceEvent():
return destroySurface(_that);case DestroySubsurfaceEvent():
return destroySubsurface(_that);case InteractiveMoveEvent():
return interactiveMove(_that);case InteractiveResizeEvent():
return interactiveResize(_that);case MonitorLayoutChangedEvent():
return monitorLayoutChanged(_that);case SetEnvironmentVariablesEvent():
return setEnvironmentVariables(_that);case GestureSwipeBeginEvent():
return gestureSwipeBegin(_that);case GestureSwipeUpdateEvent():
return gestureSwipeUpdate(_that);case GestureSwipeEndEvent():
return gestureSwipeEnd(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( NewSurfaceEvent value)?  newSurface,TResult? Function( NewSubsurfaceEvent value)?  newSubsurface,TResult? Function( MetaWindowCreatedEvent value)?  metaWindowCreated,TResult? Function( MetaWindowPatchEvent value)?  metaWindowPatch,TResult? Function( MetaWindowRemovedEvent value)?  metaWindowRemoved,TResult? Function( MetaPopupCreatedEvent value)?  metaPopupCreated,TResult? Function( MetaPopupPatchEvent value)?  metaPopupPatch,TResult? Function( MetaPopupRemovedEvent value)?  metaPopupRemoved,TResult? Function( CommitSurfaceEvent value)?  commitSurface,TResult? Function( DestroySurfaceEvent value)?  destroySurface,TResult? Function( DestroySubsurfaceEvent value)?  destroySubsurface,TResult? Function( InteractiveMoveEvent value)?  interactiveMove,TResult? Function( InteractiveResizeEvent value)?  interactiveResize,TResult? Function( MonitorLayoutChangedEvent value)?  monitorLayoutChanged,TResult? Function( SetEnvironmentVariablesEvent value)?  setEnvironmentVariables,TResult? Function( GestureSwipeBeginEvent value)?  gestureSwipeBegin,TResult? Function( GestureSwipeUpdateEvent value)?  gestureSwipeUpdate,TResult? Function( GestureSwipeEndEvent value)?  gestureSwipeEnd,}){
final _that = this;
switch (_that) {
case NewSurfaceEvent() when newSurface != null:
return newSurface(_that);case NewSubsurfaceEvent() when newSubsurface != null:
return newSubsurface(_that);case MetaWindowCreatedEvent() when metaWindowCreated != null:
return metaWindowCreated(_that);case MetaWindowPatchEvent() when metaWindowPatch != null:
return metaWindowPatch(_that);case MetaWindowRemovedEvent() when metaWindowRemoved != null:
return metaWindowRemoved(_that);case MetaPopupCreatedEvent() when metaPopupCreated != null:
return metaPopupCreated(_that);case MetaPopupPatchEvent() when metaPopupPatch != null:
return metaPopupPatch(_that);case MetaPopupRemovedEvent() when metaPopupRemoved != null:
return metaPopupRemoved(_that);case CommitSurfaceEvent() when commitSurface != null:
return commitSurface(_that);case DestroySurfaceEvent() when destroySurface != null:
return destroySurface(_that);case DestroySubsurfaceEvent() when destroySubsurface != null:
return destroySubsurface(_that);case InteractiveMoveEvent() when interactiveMove != null:
return interactiveMove(_that);case InteractiveResizeEvent() when interactiveResize != null:
return interactiveResize(_that);case MonitorLayoutChangedEvent() when monitorLayoutChanged != null:
return monitorLayoutChanged(_that);case SetEnvironmentVariablesEvent() when setEnvironmentVariables != null:
return setEnvironmentVariables(_that);case GestureSwipeBeginEvent() when gestureSwipeBegin != null:
return gestureSwipeBegin(_that);case GestureSwipeUpdateEvent() when gestureSwipeUpdate != null:
return gestureSwipeUpdate(_that);case GestureSwipeEndEvent() when gestureSwipeEnd != null:
return gestureSwipeEnd(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String method,  NewSurfaceMessage message)?  newSurface,TResult Function( String method,  NewSubsurfaceMessage message)?  newSubsurface,TResult Function( String method,  MetaWindowCreatedMessage message)?  metaWindowCreated,TResult Function( String method,  MetaWindowPatchMessage message)?  metaWindowPatch,TResult Function( String method,  MetaWindowRemovedMessage message)?  metaWindowRemoved,TResult Function( String method,  MetaPopupCreatedMessage message)?  metaPopupCreated,TResult Function( String method,  MetaPopupPatchMessage message)?  metaPopupPatch,TResult Function( String method,  MetaPopupRemovedMessage message)?  metaPopupRemoved,TResult Function( String method,  CommitSurfaceMessage message)?  commitSurface,TResult Function( String method,  DestroySurfaceMessage message)?  destroySurface,TResult Function( String method,  DestroySubsurfaceMessage message)?  destroySubsurface,TResult Function( String method,  InteractiveMoveMessage message)?  interactiveMove,TResult Function( String method,  InteractiveResizeMessage message)?  interactiveResize,TResult Function( String method,  MonitorLayoutChangedMessage message)?  monitorLayoutChanged,TResult Function( String method,  SetEnvironmentVariablesMessage message)?  setEnvironmentVariables,TResult Function( String method,  GestureSwipeBeginMessage message)?  gestureSwipeBegin,TResult Function( String method,  GestureSwipeUpdateMessage message)?  gestureSwipeUpdate,TResult Function( String method,  GestureSwipeEndMessage message)?  gestureSwipeEnd,required TResult orElse(),}) {final _that = this;
switch (_that) {
case NewSurfaceEvent() when newSurface != null:
return newSurface(_that.method,_that.message);case NewSubsurfaceEvent() when newSubsurface != null:
return newSubsurface(_that.method,_that.message);case MetaWindowCreatedEvent() when metaWindowCreated != null:
return metaWindowCreated(_that.method,_that.message);case MetaWindowPatchEvent() when metaWindowPatch != null:
return metaWindowPatch(_that.method,_that.message);case MetaWindowRemovedEvent() when metaWindowRemoved != null:
return metaWindowRemoved(_that.method,_that.message);case MetaPopupCreatedEvent() when metaPopupCreated != null:
return metaPopupCreated(_that.method,_that.message);case MetaPopupPatchEvent() when metaPopupPatch != null:
return metaPopupPatch(_that.method,_that.message);case MetaPopupRemovedEvent() when metaPopupRemoved != null:
return metaPopupRemoved(_that.method,_that.message);case CommitSurfaceEvent() when commitSurface != null:
return commitSurface(_that.method,_that.message);case DestroySurfaceEvent() when destroySurface != null:
return destroySurface(_that.method,_that.message);case DestroySubsurfaceEvent() when destroySubsurface != null:
return destroySubsurface(_that.method,_that.message);case InteractiveMoveEvent() when interactiveMove != null:
return interactiveMove(_that.method,_that.message);case InteractiveResizeEvent() when interactiveResize != null:
return interactiveResize(_that.method,_that.message);case MonitorLayoutChangedEvent() when monitorLayoutChanged != null:
return monitorLayoutChanged(_that.method,_that.message);case SetEnvironmentVariablesEvent() when setEnvironmentVariables != null:
return setEnvironmentVariables(_that.method,_that.message);case GestureSwipeBeginEvent() when gestureSwipeBegin != null:
return gestureSwipeBegin(_that.method,_that.message);case GestureSwipeUpdateEvent() when gestureSwipeUpdate != null:
return gestureSwipeUpdate(_that.method,_that.message);case GestureSwipeEndEvent() when gestureSwipeEnd != null:
return gestureSwipeEnd(_that.method,_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String method,  NewSurfaceMessage message)  newSurface,required TResult Function( String method,  NewSubsurfaceMessage message)  newSubsurface,required TResult Function( String method,  MetaWindowCreatedMessage message)  metaWindowCreated,required TResult Function( String method,  MetaWindowPatchMessage message)  metaWindowPatch,required TResult Function( String method,  MetaWindowRemovedMessage message)  metaWindowRemoved,required TResult Function( String method,  MetaPopupCreatedMessage message)  metaPopupCreated,required TResult Function( String method,  MetaPopupPatchMessage message)  metaPopupPatch,required TResult Function( String method,  MetaPopupRemovedMessage message)  metaPopupRemoved,required TResult Function( String method,  CommitSurfaceMessage message)  commitSurface,required TResult Function( String method,  DestroySurfaceMessage message)  destroySurface,required TResult Function( String method,  DestroySubsurfaceMessage message)  destroySubsurface,required TResult Function( String method,  InteractiveMoveMessage message)  interactiveMove,required TResult Function( String method,  InteractiveResizeMessage message)  interactiveResize,required TResult Function( String method,  MonitorLayoutChangedMessage message)  monitorLayoutChanged,required TResult Function( String method,  SetEnvironmentVariablesMessage message)  setEnvironmentVariables,required TResult Function( String method,  GestureSwipeBeginMessage message)  gestureSwipeBegin,required TResult Function( String method,  GestureSwipeUpdateMessage message)  gestureSwipeUpdate,required TResult Function( String method,  GestureSwipeEndMessage message)  gestureSwipeEnd,}) {final _that = this;
switch (_that) {
case NewSurfaceEvent():
return newSurface(_that.method,_that.message);case NewSubsurfaceEvent():
return newSubsurface(_that.method,_that.message);case MetaWindowCreatedEvent():
return metaWindowCreated(_that.method,_that.message);case MetaWindowPatchEvent():
return metaWindowPatch(_that.method,_that.message);case MetaWindowRemovedEvent():
return metaWindowRemoved(_that.method,_that.message);case MetaPopupCreatedEvent():
return metaPopupCreated(_that.method,_that.message);case MetaPopupPatchEvent():
return metaPopupPatch(_that.method,_that.message);case MetaPopupRemovedEvent():
return metaPopupRemoved(_that.method,_that.message);case CommitSurfaceEvent():
return commitSurface(_that.method,_that.message);case DestroySurfaceEvent():
return destroySurface(_that.method,_that.message);case DestroySubsurfaceEvent():
return destroySubsurface(_that.method,_that.message);case InteractiveMoveEvent():
return interactiveMove(_that.method,_that.message);case InteractiveResizeEvent():
return interactiveResize(_that.method,_that.message);case MonitorLayoutChangedEvent():
return monitorLayoutChanged(_that.method,_that.message);case SetEnvironmentVariablesEvent():
return setEnvironmentVariables(_that.method,_that.message);case GestureSwipeBeginEvent():
return gestureSwipeBegin(_that.method,_that.message);case GestureSwipeUpdateEvent():
return gestureSwipeUpdate(_that.method,_that.message);case GestureSwipeEndEvent():
return gestureSwipeEnd(_that.method,_that.message);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String method,  NewSurfaceMessage message)?  newSurface,TResult? Function( String method,  NewSubsurfaceMessage message)?  newSubsurface,TResult? Function( String method,  MetaWindowCreatedMessage message)?  metaWindowCreated,TResult? Function( String method,  MetaWindowPatchMessage message)?  metaWindowPatch,TResult? Function( String method,  MetaWindowRemovedMessage message)?  metaWindowRemoved,TResult? Function( String method,  MetaPopupCreatedMessage message)?  metaPopupCreated,TResult? Function( String method,  MetaPopupPatchMessage message)?  metaPopupPatch,TResult? Function( String method,  MetaPopupRemovedMessage message)?  metaPopupRemoved,TResult? Function( String method,  CommitSurfaceMessage message)?  commitSurface,TResult? Function( String method,  DestroySurfaceMessage message)?  destroySurface,TResult? Function( String method,  DestroySubsurfaceMessage message)?  destroySubsurface,TResult? Function( String method,  InteractiveMoveMessage message)?  interactiveMove,TResult? Function( String method,  InteractiveResizeMessage message)?  interactiveResize,TResult? Function( String method,  MonitorLayoutChangedMessage message)?  monitorLayoutChanged,TResult? Function( String method,  SetEnvironmentVariablesMessage message)?  setEnvironmentVariables,TResult? Function( String method,  GestureSwipeBeginMessage message)?  gestureSwipeBegin,TResult? Function( String method,  GestureSwipeUpdateMessage message)?  gestureSwipeUpdate,TResult? Function( String method,  GestureSwipeEndMessage message)?  gestureSwipeEnd,}) {final _that = this;
switch (_that) {
case NewSurfaceEvent() when newSurface != null:
return newSurface(_that.method,_that.message);case NewSubsurfaceEvent() when newSubsurface != null:
return newSubsurface(_that.method,_that.message);case MetaWindowCreatedEvent() when metaWindowCreated != null:
return metaWindowCreated(_that.method,_that.message);case MetaWindowPatchEvent() when metaWindowPatch != null:
return metaWindowPatch(_that.method,_that.message);case MetaWindowRemovedEvent() when metaWindowRemoved != null:
return metaWindowRemoved(_that.method,_that.message);case MetaPopupCreatedEvent() when metaPopupCreated != null:
return metaPopupCreated(_that.method,_that.message);case MetaPopupPatchEvent() when metaPopupPatch != null:
return metaPopupPatch(_that.method,_that.message);case MetaPopupRemovedEvent() when metaPopupRemoved != null:
return metaPopupRemoved(_that.method,_that.message);case CommitSurfaceEvent() when commitSurface != null:
return commitSurface(_that.method,_that.message);case DestroySurfaceEvent() when destroySurface != null:
return destroySurface(_that.method,_that.message);case DestroySubsurfaceEvent() when destroySubsurface != null:
return destroySubsurface(_that.method,_that.message);case InteractiveMoveEvent() when interactiveMove != null:
return interactiveMove(_that.method,_that.message);case InteractiveResizeEvent() when interactiveResize != null:
return interactiveResize(_that.method,_that.message);case MonitorLayoutChangedEvent() when monitorLayoutChanged != null:
return monitorLayoutChanged(_that.method,_that.message);case SetEnvironmentVariablesEvent() when setEnvironmentVariables != null:
return setEnvironmentVariables(_that.method,_that.message);case GestureSwipeBeginEvent() when gestureSwipeBegin != null:
return gestureSwipeBegin(_that.method,_that.message);case GestureSwipeUpdateEvent() when gestureSwipeUpdate != null:
return gestureSwipeUpdate(_that.method,_that.message);case GestureSwipeEndEvent() when gestureSwipeEnd != null:
return gestureSwipeEnd(_that.method,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class NewSurfaceEvent implements PlatformEvent {
  const NewSurfaceEvent({required this.method, required this.message});
  factory NewSurfaceEvent.fromJson(Map<String, dynamic> json) => _$NewSurfaceEventFromJson(json);

@override final  String method;
@override final  NewSurfaceMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSurfaceEventCopyWith<NewSurfaceEvent> get copyWith => _$NewSurfaceEventCopyWithImpl<NewSurfaceEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NewSurfaceEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSurfaceEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.newSurface(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $NewSurfaceEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $NewSurfaceEventCopyWith(NewSurfaceEvent value, $Res Function(NewSurfaceEvent) _then) = _$NewSurfaceEventCopyWithImpl;
@override @useResult
$Res call({
 String method, NewSurfaceMessage message
});


$NewSurfaceMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$NewSurfaceEventCopyWithImpl<$Res>
    implements $NewSurfaceEventCopyWith<$Res> {
  _$NewSurfaceEventCopyWithImpl(this._self, this._then);

  final NewSurfaceEvent _self;
  final $Res Function(NewSurfaceEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(NewSurfaceEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as NewSurfaceMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSurfaceMessageCopyWith<$Res> get message {
  
  return $NewSurfaceMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class NewSubsurfaceEvent implements PlatformEvent {
  const NewSubsurfaceEvent({required this.method, required this.message});
  factory NewSubsurfaceEvent.fromJson(Map<String, dynamic> json) => _$NewSubsurfaceEventFromJson(json);

@override final  String method;
@override final  NewSubsurfaceMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSubsurfaceEventCopyWith<NewSubsurfaceEvent> get copyWith => _$NewSubsurfaceEventCopyWithImpl<NewSubsurfaceEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NewSubsurfaceEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSubsurfaceEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.newSubsurface(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $NewSubsurfaceEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $NewSubsurfaceEventCopyWith(NewSubsurfaceEvent value, $Res Function(NewSubsurfaceEvent) _then) = _$NewSubsurfaceEventCopyWithImpl;
@override @useResult
$Res call({
 String method, NewSubsurfaceMessage message
});


$NewSubsurfaceMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$NewSubsurfaceEventCopyWithImpl<$Res>
    implements $NewSubsurfaceEventCopyWith<$Res> {
  _$NewSubsurfaceEventCopyWithImpl(this._self, this._then);

  final NewSubsurfaceEvent _self;
  final $Res Function(NewSubsurfaceEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(NewSubsurfaceEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as NewSubsurfaceMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSubsurfaceMessageCopyWith<$Res> get message {
  
  return $NewSubsurfaceMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class MetaWindowCreatedEvent implements PlatformEvent {
  const MetaWindowCreatedEvent({required this.method, required this.message});
  factory MetaWindowCreatedEvent.fromJson(Map<String, dynamic> json) => _$MetaWindowCreatedEventFromJson(json);

@override final  String method;
@override final  MetaWindowCreatedMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaWindowCreatedEventCopyWith<MetaWindowCreatedEvent> get copyWith => _$MetaWindowCreatedEventCopyWithImpl<MetaWindowCreatedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaWindowCreatedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaWindowCreatedEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.metaWindowCreated(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $MetaWindowCreatedEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $MetaWindowCreatedEventCopyWith(MetaWindowCreatedEvent value, $Res Function(MetaWindowCreatedEvent) _then) = _$MetaWindowCreatedEventCopyWithImpl;
@override @useResult
$Res call({
 String method, MetaWindowCreatedMessage message
});


$MetaWindowCreatedMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$MetaWindowCreatedEventCopyWithImpl<$Res>
    implements $MetaWindowCreatedEventCopyWith<$Res> {
  _$MetaWindowCreatedEventCopyWithImpl(this._self, this._then);

  final MetaWindowCreatedEvent _self;
  final $Res Function(MetaWindowCreatedEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(MetaWindowCreatedEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as MetaWindowCreatedMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetaWindowCreatedMessageCopyWith<$Res> get message {
  
  return $MetaWindowCreatedMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class MetaWindowPatchEvent implements PlatformEvent {
  const MetaWindowPatchEvent({required this.method, required this.message});
  factory MetaWindowPatchEvent.fromJson(Map<String, dynamic> json) => _$MetaWindowPatchEventFromJson(json);

@override final  String method;
@override final  MetaWindowPatchMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaWindowPatchEventCopyWith<MetaWindowPatchEvent> get copyWith => _$MetaWindowPatchEventCopyWithImpl<MetaWindowPatchEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaWindowPatchEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaWindowPatchEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.metaWindowPatch(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $MetaWindowPatchEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $MetaWindowPatchEventCopyWith(MetaWindowPatchEvent value, $Res Function(MetaWindowPatchEvent) _then) = _$MetaWindowPatchEventCopyWithImpl;
@override @useResult
$Res call({
 String method, MetaWindowPatchMessage message
});


$MetaWindowPatchMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$MetaWindowPatchEventCopyWithImpl<$Res>
    implements $MetaWindowPatchEventCopyWith<$Res> {
  _$MetaWindowPatchEventCopyWithImpl(this._self, this._then);

  final MetaWindowPatchEvent _self;
  final $Res Function(MetaWindowPatchEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(MetaWindowPatchEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as MetaWindowPatchMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetaWindowPatchMessageCopyWith<$Res> get message {
  
  return $MetaWindowPatchMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class MetaWindowRemovedEvent implements PlatformEvent {
  const MetaWindowRemovedEvent({required this.method, required this.message});
  factory MetaWindowRemovedEvent.fromJson(Map<String, dynamic> json) => _$MetaWindowRemovedEventFromJson(json);

@override final  String method;
@override final  MetaWindowRemovedMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaWindowRemovedEventCopyWith<MetaWindowRemovedEvent> get copyWith => _$MetaWindowRemovedEventCopyWithImpl<MetaWindowRemovedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaWindowRemovedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaWindowRemovedEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.metaWindowRemoved(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $MetaWindowRemovedEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $MetaWindowRemovedEventCopyWith(MetaWindowRemovedEvent value, $Res Function(MetaWindowRemovedEvent) _then) = _$MetaWindowRemovedEventCopyWithImpl;
@override @useResult
$Res call({
 String method, MetaWindowRemovedMessage message
});


$MetaWindowRemovedMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$MetaWindowRemovedEventCopyWithImpl<$Res>
    implements $MetaWindowRemovedEventCopyWith<$Res> {
  _$MetaWindowRemovedEventCopyWithImpl(this._self, this._then);

  final MetaWindowRemovedEvent _self;
  final $Res Function(MetaWindowRemovedEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(MetaWindowRemovedEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as MetaWindowRemovedMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetaWindowRemovedMessageCopyWith<$Res> get message {
  
  return $MetaWindowRemovedMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class MetaPopupCreatedEvent implements PlatformEvent {
  const MetaPopupCreatedEvent({required this.method, required this.message});
  factory MetaPopupCreatedEvent.fromJson(Map<String, dynamic> json) => _$MetaPopupCreatedEventFromJson(json);

@override final  String method;
@override final  MetaPopupCreatedMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaPopupCreatedEventCopyWith<MetaPopupCreatedEvent> get copyWith => _$MetaPopupCreatedEventCopyWithImpl<MetaPopupCreatedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaPopupCreatedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaPopupCreatedEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.metaPopupCreated(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $MetaPopupCreatedEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $MetaPopupCreatedEventCopyWith(MetaPopupCreatedEvent value, $Res Function(MetaPopupCreatedEvent) _then) = _$MetaPopupCreatedEventCopyWithImpl;
@override @useResult
$Res call({
 String method, MetaPopupCreatedMessage message
});


$MetaPopupCreatedMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$MetaPopupCreatedEventCopyWithImpl<$Res>
    implements $MetaPopupCreatedEventCopyWith<$Res> {
  _$MetaPopupCreatedEventCopyWithImpl(this._self, this._then);

  final MetaPopupCreatedEvent _self;
  final $Res Function(MetaPopupCreatedEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(MetaPopupCreatedEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as MetaPopupCreatedMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetaPopupCreatedMessageCopyWith<$Res> get message {
  
  return $MetaPopupCreatedMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class MetaPopupPatchEvent implements PlatformEvent {
  const MetaPopupPatchEvent({required this.method, required this.message});
  factory MetaPopupPatchEvent.fromJson(Map<String, dynamic> json) => _$MetaPopupPatchEventFromJson(json);

@override final  String method;
@override final  MetaPopupPatchMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaPopupPatchEventCopyWith<MetaPopupPatchEvent> get copyWith => _$MetaPopupPatchEventCopyWithImpl<MetaPopupPatchEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaPopupPatchEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaPopupPatchEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.metaPopupPatch(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $MetaPopupPatchEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $MetaPopupPatchEventCopyWith(MetaPopupPatchEvent value, $Res Function(MetaPopupPatchEvent) _then) = _$MetaPopupPatchEventCopyWithImpl;
@override @useResult
$Res call({
 String method, MetaPopupPatchMessage message
});


$MetaPopupPatchMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$MetaPopupPatchEventCopyWithImpl<$Res>
    implements $MetaPopupPatchEventCopyWith<$Res> {
  _$MetaPopupPatchEventCopyWithImpl(this._self, this._then);

  final MetaPopupPatchEvent _self;
  final $Res Function(MetaPopupPatchEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(MetaPopupPatchEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as MetaPopupPatchMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetaPopupPatchMessageCopyWith<$Res> get message {
  
  return $MetaPopupPatchMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class MetaPopupRemovedEvent implements PlatformEvent {
  const MetaPopupRemovedEvent({required this.method, required this.message});
  factory MetaPopupRemovedEvent.fromJson(Map<String, dynamic> json) => _$MetaPopupRemovedEventFromJson(json);

@override final  String method;
@override final  MetaPopupRemovedMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaPopupRemovedEventCopyWith<MetaPopupRemovedEvent> get copyWith => _$MetaPopupRemovedEventCopyWithImpl<MetaPopupRemovedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaPopupRemovedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaPopupRemovedEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.metaPopupRemoved(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $MetaPopupRemovedEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $MetaPopupRemovedEventCopyWith(MetaPopupRemovedEvent value, $Res Function(MetaPopupRemovedEvent) _then) = _$MetaPopupRemovedEventCopyWithImpl;
@override @useResult
$Res call({
 String method, MetaPopupRemovedMessage message
});


$MetaPopupRemovedMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$MetaPopupRemovedEventCopyWithImpl<$Res>
    implements $MetaPopupRemovedEventCopyWith<$Res> {
  _$MetaPopupRemovedEventCopyWithImpl(this._self, this._then);

  final MetaPopupRemovedEvent _self;
  final $Res Function(MetaPopupRemovedEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(MetaPopupRemovedEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as MetaPopupRemovedMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetaPopupRemovedMessageCopyWith<$Res> get message {
  
  return $MetaPopupRemovedMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class CommitSurfaceEvent implements PlatformEvent {
  const CommitSurfaceEvent({required this.method, required this.message});
  factory CommitSurfaceEvent.fromJson(Map<String, dynamic> json) => _$CommitSurfaceEventFromJson(json);

@override final  String method;
@override final  CommitSurfaceMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommitSurfaceEventCopyWith<CommitSurfaceEvent> get copyWith => _$CommitSurfaceEventCopyWithImpl<CommitSurfaceEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommitSurfaceEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommitSurfaceEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.commitSurface(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $CommitSurfaceEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $CommitSurfaceEventCopyWith(CommitSurfaceEvent value, $Res Function(CommitSurfaceEvent) _then) = _$CommitSurfaceEventCopyWithImpl;
@override @useResult
$Res call({
 String method, CommitSurfaceMessage message
});


$CommitSurfaceMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$CommitSurfaceEventCopyWithImpl<$Res>
    implements $CommitSurfaceEventCopyWith<$Res> {
  _$CommitSurfaceEventCopyWithImpl(this._self, this._then);

  final CommitSurfaceEvent _self;
  final $Res Function(CommitSurfaceEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(CommitSurfaceEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as CommitSurfaceMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommitSurfaceMessageCopyWith<$Res> get message {
  
  return $CommitSurfaceMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class DestroySurfaceEvent implements PlatformEvent {
  const DestroySurfaceEvent({required this.method, required this.message});
  factory DestroySurfaceEvent.fromJson(Map<String, dynamic> json) => _$DestroySurfaceEventFromJson(json);

@override final  String method;
@override final  DestroySurfaceMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DestroySurfaceEventCopyWith<DestroySurfaceEvent> get copyWith => _$DestroySurfaceEventCopyWithImpl<DestroySurfaceEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DestroySurfaceEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DestroySurfaceEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.destroySurface(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $DestroySurfaceEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $DestroySurfaceEventCopyWith(DestroySurfaceEvent value, $Res Function(DestroySurfaceEvent) _then) = _$DestroySurfaceEventCopyWithImpl;
@override @useResult
$Res call({
 String method, DestroySurfaceMessage message
});


$DestroySurfaceMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$DestroySurfaceEventCopyWithImpl<$Res>
    implements $DestroySurfaceEventCopyWith<$Res> {
  _$DestroySurfaceEventCopyWithImpl(this._self, this._then);

  final DestroySurfaceEvent _self;
  final $Res Function(DestroySurfaceEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(DestroySurfaceEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as DestroySurfaceMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DestroySurfaceMessageCopyWith<$Res> get message {
  
  return $DestroySurfaceMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class DestroySubsurfaceEvent implements PlatformEvent {
  const DestroySubsurfaceEvent({required this.method, required this.message});
  factory DestroySubsurfaceEvent.fromJson(Map<String, dynamic> json) => _$DestroySubsurfaceEventFromJson(json);

@override final  String method;
@override final  DestroySubsurfaceMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DestroySubsurfaceEventCopyWith<DestroySubsurfaceEvent> get copyWith => _$DestroySubsurfaceEventCopyWithImpl<DestroySubsurfaceEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DestroySubsurfaceEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DestroySubsurfaceEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.destroySubsurface(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $DestroySubsurfaceEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $DestroySubsurfaceEventCopyWith(DestroySubsurfaceEvent value, $Res Function(DestroySubsurfaceEvent) _then) = _$DestroySubsurfaceEventCopyWithImpl;
@override @useResult
$Res call({
 String method, DestroySubsurfaceMessage message
});


$DestroySubsurfaceMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$DestroySubsurfaceEventCopyWithImpl<$Res>
    implements $DestroySubsurfaceEventCopyWith<$Res> {
  _$DestroySubsurfaceEventCopyWithImpl(this._self, this._then);

  final DestroySubsurfaceEvent _self;
  final $Res Function(DestroySubsurfaceEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(DestroySubsurfaceEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as DestroySubsurfaceMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DestroySubsurfaceMessageCopyWith<$Res> get message {
  
  return $DestroySubsurfaceMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class InteractiveMoveEvent implements PlatformEvent {
  const InteractiveMoveEvent({required this.method, required this.message});
  factory InteractiveMoveEvent.fromJson(Map<String, dynamic> json) => _$InteractiveMoveEventFromJson(json);

@override final  String method;
@override final  InteractiveMoveMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InteractiveMoveEventCopyWith<InteractiveMoveEvent> get copyWith => _$InteractiveMoveEventCopyWithImpl<InteractiveMoveEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InteractiveMoveEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InteractiveMoveEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.interactiveMove(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $InteractiveMoveEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $InteractiveMoveEventCopyWith(InteractiveMoveEvent value, $Res Function(InteractiveMoveEvent) _then) = _$InteractiveMoveEventCopyWithImpl;
@override @useResult
$Res call({
 String method, InteractiveMoveMessage message
});


$InteractiveMoveMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$InteractiveMoveEventCopyWithImpl<$Res>
    implements $InteractiveMoveEventCopyWith<$Res> {
  _$InteractiveMoveEventCopyWithImpl(this._self, this._then);

  final InteractiveMoveEvent _self;
  final $Res Function(InteractiveMoveEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(InteractiveMoveEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as InteractiveMoveMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InteractiveMoveMessageCopyWith<$Res> get message {
  
  return $InteractiveMoveMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class InteractiveResizeEvent implements PlatformEvent {
  const InteractiveResizeEvent({required this.method, required this.message});
  factory InteractiveResizeEvent.fromJson(Map<String, dynamic> json) => _$InteractiveResizeEventFromJson(json);

@override final  String method;
@override final  InteractiveResizeMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InteractiveResizeEventCopyWith<InteractiveResizeEvent> get copyWith => _$InteractiveResizeEventCopyWithImpl<InteractiveResizeEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InteractiveResizeEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InteractiveResizeEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.interactiveResize(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $InteractiveResizeEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $InteractiveResizeEventCopyWith(InteractiveResizeEvent value, $Res Function(InteractiveResizeEvent) _then) = _$InteractiveResizeEventCopyWithImpl;
@override @useResult
$Res call({
 String method, InteractiveResizeMessage message
});


$InteractiveResizeMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$InteractiveResizeEventCopyWithImpl<$Res>
    implements $InteractiveResizeEventCopyWith<$Res> {
  _$InteractiveResizeEventCopyWithImpl(this._self, this._then);

  final InteractiveResizeEvent _self;
  final $Res Function(InteractiveResizeEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(InteractiveResizeEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as InteractiveResizeMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InteractiveResizeMessageCopyWith<$Res> get message {
  
  return $InteractiveResizeMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class MonitorLayoutChangedEvent implements PlatformEvent {
  const MonitorLayoutChangedEvent({required this.method, required this.message});
  factory MonitorLayoutChangedEvent.fromJson(Map<String, dynamic> json) => _$MonitorLayoutChangedEventFromJson(json);

@override final  String method;
@override final  MonitorLayoutChangedMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MonitorLayoutChangedEventCopyWith<MonitorLayoutChangedEvent> get copyWith => _$MonitorLayoutChangedEventCopyWithImpl<MonitorLayoutChangedEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MonitorLayoutChangedEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MonitorLayoutChangedEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.monitorLayoutChanged(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $MonitorLayoutChangedEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $MonitorLayoutChangedEventCopyWith(MonitorLayoutChangedEvent value, $Res Function(MonitorLayoutChangedEvent) _then) = _$MonitorLayoutChangedEventCopyWithImpl;
@override @useResult
$Res call({
 String method, MonitorLayoutChangedMessage message
});


$MonitorLayoutChangedMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$MonitorLayoutChangedEventCopyWithImpl<$Res>
    implements $MonitorLayoutChangedEventCopyWith<$Res> {
  _$MonitorLayoutChangedEventCopyWithImpl(this._self, this._then);

  final MonitorLayoutChangedEvent _self;
  final $Res Function(MonitorLayoutChangedEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(MonitorLayoutChangedEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as MonitorLayoutChangedMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MonitorLayoutChangedMessageCopyWith<$Res> get message {
  
  return $MonitorLayoutChangedMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SetEnvironmentVariablesEvent implements PlatformEvent {
  const SetEnvironmentVariablesEvent({required this.method, required this.message});
  factory SetEnvironmentVariablesEvent.fromJson(Map<String, dynamic> json) => _$SetEnvironmentVariablesEventFromJson(json);

@override final  String method;
@override final  SetEnvironmentVariablesMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetEnvironmentVariablesEventCopyWith<SetEnvironmentVariablesEvent> get copyWith => _$SetEnvironmentVariablesEventCopyWithImpl<SetEnvironmentVariablesEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SetEnvironmentVariablesEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetEnvironmentVariablesEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.setEnvironmentVariables(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $SetEnvironmentVariablesEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $SetEnvironmentVariablesEventCopyWith(SetEnvironmentVariablesEvent value, $Res Function(SetEnvironmentVariablesEvent) _then) = _$SetEnvironmentVariablesEventCopyWithImpl;
@override @useResult
$Res call({
 String method, SetEnvironmentVariablesMessage message
});


$SetEnvironmentVariablesMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$SetEnvironmentVariablesEventCopyWithImpl<$Res>
    implements $SetEnvironmentVariablesEventCopyWith<$Res> {
  _$SetEnvironmentVariablesEventCopyWithImpl(this._self, this._then);

  final SetEnvironmentVariablesEvent _self;
  final $Res Function(SetEnvironmentVariablesEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(SetEnvironmentVariablesEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as SetEnvironmentVariablesMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SetEnvironmentVariablesMessageCopyWith<$Res> get message {
  
  return $SetEnvironmentVariablesMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class GestureSwipeBeginEvent implements PlatformEvent {
  const GestureSwipeBeginEvent({required this.method, required this.message});
  factory GestureSwipeBeginEvent.fromJson(Map<String, dynamic> json) => _$GestureSwipeBeginEventFromJson(json);

@override final  String method;
@override final  GestureSwipeBeginMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GestureSwipeBeginEventCopyWith<GestureSwipeBeginEvent> get copyWith => _$GestureSwipeBeginEventCopyWithImpl<GestureSwipeBeginEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GestureSwipeBeginEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GestureSwipeBeginEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.gestureSwipeBegin(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $GestureSwipeBeginEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $GestureSwipeBeginEventCopyWith(GestureSwipeBeginEvent value, $Res Function(GestureSwipeBeginEvent) _then) = _$GestureSwipeBeginEventCopyWithImpl;
@override @useResult
$Res call({
 String method, GestureSwipeBeginMessage message
});


$GestureSwipeBeginMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$GestureSwipeBeginEventCopyWithImpl<$Res>
    implements $GestureSwipeBeginEventCopyWith<$Res> {
  _$GestureSwipeBeginEventCopyWithImpl(this._self, this._then);

  final GestureSwipeBeginEvent _self;
  final $Res Function(GestureSwipeBeginEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(GestureSwipeBeginEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as GestureSwipeBeginMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GestureSwipeBeginMessageCopyWith<$Res> get message {
  
  return $GestureSwipeBeginMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class GestureSwipeUpdateEvent implements PlatformEvent {
  const GestureSwipeUpdateEvent({required this.method, required this.message});
  factory GestureSwipeUpdateEvent.fromJson(Map<String, dynamic> json) => _$GestureSwipeUpdateEventFromJson(json);

@override final  String method;
@override final  GestureSwipeUpdateMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GestureSwipeUpdateEventCopyWith<GestureSwipeUpdateEvent> get copyWith => _$GestureSwipeUpdateEventCopyWithImpl<GestureSwipeUpdateEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GestureSwipeUpdateEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GestureSwipeUpdateEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.gestureSwipeUpdate(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $GestureSwipeUpdateEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $GestureSwipeUpdateEventCopyWith(GestureSwipeUpdateEvent value, $Res Function(GestureSwipeUpdateEvent) _then) = _$GestureSwipeUpdateEventCopyWithImpl;
@override @useResult
$Res call({
 String method, GestureSwipeUpdateMessage message
});


$GestureSwipeUpdateMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$GestureSwipeUpdateEventCopyWithImpl<$Res>
    implements $GestureSwipeUpdateEventCopyWith<$Res> {
  _$GestureSwipeUpdateEventCopyWithImpl(this._self, this._then);

  final GestureSwipeUpdateEvent _self;
  final $Res Function(GestureSwipeUpdateEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(GestureSwipeUpdateEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as GestureSwipeUpdateMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GestureSwipeUpdateMessageCopyWith<$Res> get message {
  
  return $GestureSwipeUpdateMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class GestureSwipeEndEvent implements PlatformEvent {
  const GestureSwipeEndEvent({required this.method, required this.message});
  factory GestureSwipeEndEvent.fromJson(Map<String, dynamic> json) => _$GestureSwipeEndEventFromJson(json);

@override final  String method;
@override final  GestureSwipeEndMessage message;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GestureSwipeEndEventCopyWith<GestureSwipeEndEvent> get copyWith => _$GestureSwipeEndEventCopyWithImpl<GestureSwipeEndEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GestureSwipeEndEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GestureSwipeEndEvent&&(identical(other.method, method) || other.method == method)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,message);

@override
String toString() {
  return 'PlatformEvent.gestureSwipeEnd(method: $method, message: $message)';
}


}

/// @nodoc
abstract mixin class $GestureSwipeEndEventCopyWith<$Res> implements $PlatformEventCopyWith<$Res> {
  factory $GestureSwipeEndEventCopyWith(GestureSwipeEndEvent value, $Res Function(GestureSwipeEndEvent) _then) = _$GestureSwipeEndEventCopyWithImpl;
@override @useResult
$Res call({
 String method, GestureSwipeEndMessage message
});


$GestureSwipeEndMessageCopyWith<$Res> get message;

}
/// @nodoc
class _$GestureSwipeEndEventCopyWithImpl<$Res>
    implements $GestureSwipeEndEventCopyWith<$Res> {
  _$GestureSwipeEndEventCopyWithImpl(this._self, this._then);

  final GestureSwipeEndEvent _self;
  final $Res Function(GestureSwipeEndEvent) _then;

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? message = null,}) {
  return _then(GestureSwipeEndEvent(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as GestureSwipeEndMessage,
  ));
}

/// Create a copy of PlatformEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GestureSwipeEndMessageCopyWith<$Res> get message {
  
  return $GestureSwipeEndMessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

// dart format on

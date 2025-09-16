// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_manager_state.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationManagerState {

 IMap<int, Notification> get notificationMap; int get lastIndex;
/// Create a copy of NotificationManagerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationManagerStateCopyWith<NotificationManagerState> get copyWith => _$NotificationManagerStateCopyWithImpl<NotificationManagerState>(this as NotificationManagerState, _$identity);

  /// Serializes this NotificationManagerState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationManagerState&&(identical(other.notificationMap, notificationMap) || other.notificationMap == notificationMap)&&(identical(other.lastIndex, lastIndex) || other.lastIndex == lastIndex));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,notificationMap,lastIndex);

@override
String toString() {
  return 'NotificationManagerState(notificationMap: $notificationMap, lastIndex: $lastIndex)';
}


}

/// @nodoc
abstract mixin class $NotificationManagerStateCopyWith<$Res>  {
  factory $NotificationManagerStateCopyWith(NotificationManagerState value, $Res Function(NotificationManagerState) _then) = _$NotificationManagerStateCopyWithImpl;
@useResult
$Res call({
 IMap<int, Notification> notificationMap, int lastIndex
});




}
/// @nodoc
class _$NotificationManagerStateCopyWithImpl<$Res>
    implements $NotificationManagerStateCopyWith<$Res> {
  _$NotificationManagerStateCopyWithImpl(this._self, this._then);

  final NotificationManagerState _self;
  final $Res Function(NotificationManagerState) _then;

/// Create a copy of NotificationManagerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? notificationMap = null,Object? lastIndex = null,}) {
  return _then(_self.copyWith(
notificationMap: null == notificationMap ? _self.notificationMap : notificationMap // ignore: cast_nullable_to_non_nullable
as IMap<int, Notification>,lastIndex: null == lastIndex ? _self.lastIndex : lastIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationManagerState].
extension NotificationManagerStatePatterns on NotificationManagerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationManagerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationManagerState() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationManagerState value)  $default,){
final _that = this;
switch (_that) {
case _NotificationManagerState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationManagerState value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationManagerState() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IMap<int, Notification> notificationMap,  int lastIndex)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationManagerState() when $default != null:
return $default(_that.notificationMap,_that.lastIndex);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IMap<int, Notification> notificationMap,  int lastIndex)  $default,) {final _that = this;
switch (_that) {
case _NotificationManagerState():
return $default(_that.notificationMap,_that.lastIndex);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IMap<int, Notification> notificationMap,  int lastIndex)?  $default,) {final _that = this;
switch (_that) {
case _NotificationManagerState() when $default != null:
return $default(_that.notificationMap,_that.lastIndex);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationManagerState extends NotificationManagerState {
   _NotificationManagerState({required this.notificationMap, required this.lastIndex}): super._();
  factory _NotificationManagerState.fromJson(Map<String, dynamic> json) => _$NotificationManagerStateFromJson(json);

@override final  IMap<int, Notification> notificationMap;
@override final  int lastIndex;

/// Create a copy of NotificationManagerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationManagerStateCopyWith<_NotificationManagerState> get copyWith => __$NotificationManagerStateCopyWithImpl<_NotificationManagerState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationManagerStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationManagerState&&(identical(other.notificationMap, notificationMap) || other.notificationMap == notificationMap)&&(identical(other.lastIndex, lastIndex) || other.lastIndex == lastIndex));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,notificationMap,lastIndex);

@override
String toString() {
  return 'NotificationManagerState(notificationMap: $notificationMap, lastIndex: $lastIndex)';
}


}

/// @nodoc
abstract mixin class _$NotificationManagerStateCopyWith<$Res> implements $NotificationManagerStateCopyWith<$Res> {
  factory _$NotificationManagerStateCopyWith(_NotificationManagerState value, $Res Function(_NotificationManagerState) _then) = __$NotificationManagerStateCopyWithImpl;
@override @useResult
$Res call({
 IMap<int, Notification> notificationMap, int lastIndex
});




}
/// @nodoc
class __$NotificationManagerStateCopyWithImpl<$Res>
    implements _$NotificationManagerStateCopyWith<$Res> {
  __$NotificationManagerStateCopyWithImpl(this._self, this._then);

  final _NotificationManagerState _self;
  final $Res Function(_NotificationManagerState) _then;

/// Create a copy of NotificationManagerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? notificationMap = null,Object? lastIndex = null,}) {
  return _then(_NotificationManagerState(
notificationMap: null == notificationMap ? _self.notificationMap : notificationMap // ignore: cast_nullable_to_non_nullable
as IMap<int, Notification>,lastIndex: null == lastIndex ? _self.lastIndex : lastIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

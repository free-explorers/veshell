// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monitor_manager_state.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MonitorManagerState {

 ISet<MonitorId> get knownMonitorIds;
/// Create a copy of MonitorManagerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MonitorManagerStateCopyWith<MonitorManagerState> get copyWith => _$MonitorManagerStateCopyWithImpl<MonitorManagerState>(this as MonitorManagerState, _$identity);

  /// Serializes this MonitorManagerState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MonitorManagerState&&const DeepCollectionEquality().equals(other.knownMonitorIds, knownMonitorIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(knownMonitorIds));

@override
String toString() {
  return 'MonitorManagerState(knownMonitorIds: $knownMonitorIds)';
}


}

/// @nodoc
abstract mixin class $MonitorManagerStateCopyWith<$Res>  {
  factory $MonitorManagerStateCopyWith(MonitorManagerState value, $Res Function(MonitorManagerState) _then) = _$MonitorManagerStateCopyWithImpl;
@useResult
$Res call({
 ISet<MonitorId> knownMonitorIds
});




}
/// @nodoc
class _$MonitorManagerStateCopyWithImpl<$Res>
    implements $MonitorManagerStateCopyWith<$Res> {
  _$MonitorManagerStateCopyWithImpl(this._self, this._then);

  final MonitorManagerState _self;
  final $Res Function(MonitorManagerState) _then;

/// Create a copy of MonitorManagerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? knownMonitorIds = null,}) {
  return _then(_self.copyWith(
knownMonitorIds: null == knownMonitorIds ? _self.knownMonitorIds : knownMonitorIds // ignore: cast_nullable_to_non_nullable
as ISet<MonitorId>,
  ));
}

}


/// Adds pattern-matching-related methods to [MonitorManagerState].
extension MonitorManagerStatePatterns on MonitorManagerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MonitorManagerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MonitorManagerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MonitorManagerState value)  $default,){
final _that = this;
switch (_that) {
case _MonitorManagerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MonitorManagerState value)?  $default,){
final _that = this;
switch (_that) {
case _MonitorManagerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ISet<MonitorId> knownMonitorIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MonitorManagerState() when $default != null:
return $default(_that.knownMonitorIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ISet<MonitorId> knownMonitorIds)  $default,) {final _that = this;
switch (_that) {
case _MonitorManagerState():
return $default(_that.knownMonitorIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ISet<MonitorId> knownMonitorIds)?  $default,) {final _that = this;
switch (_that) {
case _MonitorManagerState() when $default != null:
return $default(_that.knownMonitorIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MonitorManagerState implements MonitorManagerState {
  const _MonitorManagerState({required this.knownMonitorIds});
  factory _MonitorManagerState.fromJson(Map<String, dynamic> json) => _$MonitorManagerStateFromJson(json);

@override final  ISet<MonitorId> knownMonitorIds;

/// Create a copy of MonitorManagerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MonitorManagerStateCopyWith<_MonitorManagerState> get copyWith => __$MonitorManagerStateCopyWithImpl<_MonitorManagerState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MonitorManagerStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MonitorManagerState&&const DeepCollectionEquality().equals(other.knownMonitorIds, knownMonitorIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(knownMonitorIds));

@override
String toString() {
  return 'MonitorManagerState(knownMonitorIds: $knownMonitorIds)';
}


}

/// @nodoc
abstract mixin class _$MonitorManagerStateCopyWith<$Res> implements $MonitorManagerStateCopyWith<$Res> {
  factory _$MonitorManagerStateCopyWith(_MonitorManagerState value, $Res Function(_MonitorManagerState) _then) = __$MonitorManagerStateCopyWithImpl;
@override @useResult
$Res call({
 ISet<MonitorId> knownMonitorIds
});




}
/// @nodoc
class __$MonitorManagerStateCopyWithImpl<$Res>
    implements _$MonitorManagerStateCopyWith<$Res> {
  __$MonitorManagerStateCopyWithImpl(this._self, this._then);

  final _MonitorManagerState _self;
  final $Res Function(_MonitorManagerState) _then;

/// Create a copy of MonitorManagerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? knownMonitorIds = null,}) {
  return _then(_MonitorManagerState(
knownMonitorIds: null == knownMonitorIds ? _self.knownMonitorIds : knownMonitorIds // ignore: cast_nullable_to_non_nullable
as ISet<MonitorId>,
  ));
}


}

// dart format on

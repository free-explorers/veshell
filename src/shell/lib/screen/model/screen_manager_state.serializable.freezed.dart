// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'screen_manager_state.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ScreenManagerState {

 ISet<ScreenId> get screenIds;
/// Create a copy of ScreenManagerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScreenManagerStateCopyWith<ScreenManagerState> get copyWith => _$ScreenManagerStateCopyWithImpl<ScreenManagerState>(this as ScreenManagerState, _$identity);

  /// Serializes this ScreenManagerState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScreenManagerState&&const DeepCollectionEquality().equals(other.screenIds, screenIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(screenIds));

@override
String toString() {
  return 'ScreenManagerState(screenIds: $screenIds)';
}


}

/// @nodoc
abstract mixin class $ScreenManagerStateCopyWith<$Res>  {
  factory $ScreenManagerStateCopyWith(ScreenManagerState value, $Res Function(ScreenManagerState) _then) = _$ScreenManagerStateCopyWithImpl;
@useResult
$Res call({
 ISet<ScreenId> screenIds
});




}
/// @nodoc
class _$ScreenManagerStateCopyWithImpl<$Res>
    implements $ScreenManagerStateCopyWith<$Res> {
  _$ScreenManagerStateCopyWithImpl(this._self, this._then);

  final ScreenManagerState _self;
  final $Res Function(ScreenManagerState) _then;

/// Create a copy of ScreenManagerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? screenIds = null,}) {
  return _then(_self.copyWith(
screenIds: null == screenIds ? _self.screenIds : screenIds // ignore: cast_nullable_to_non_nullable
as ISet<ScreenId>,
  ));
}

}


/// Adds pattern-matching-related methods to [ScreenManagerState].
extension ScreenManagerStatePatterns on ScreenManagerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScreenManagerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScreenManagerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScreenManagerState value)  $default,){
final _that = this;
switch (_that) {
case _ScreenManagerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScreenManagerState value)?  $default,){
final _that = this;
switch (_that) {
case _ScreenManagerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ISet<ScreenId> screenIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScreenManagerState() when $default != null:
return $default(_that.screenIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ISet<ScreenId> screenIds)  $default,) {final _that = this;
switch (_that) {
case _ScreenManagerState():
return $default(_that.screenIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ISet<ScreenId> screenIds)?  $default,) {final _that = this;
switch (_that) {
case _ScreenManagerState() when $default != null:
return $default(_that.screenIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ScreenManagerState implements ScreenManagerState {
  const _ScreenManagerState({required this.screenIds});
  factory _ScreenManagerState.fromJson(Map<String, dynamic> json) => _$ScreenManagerStateFromJson(json);

@override final  ISet<ScreenId> screenIds;

/// Create a copy of ScreenManagerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScreenManagerStateCopyWith<_ScreenManagerState> get copyWith => __$ScreenManagerStateCopyWithImpl<_ScreenManagerState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScreenManagerStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScreenManagerState&&const DeepCollectionEquality().equals(other.screenIds, screenIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(screenIds));

@override
String toString() {
  return 'ScreenManagerState(screenIds: $screenIds)';
}


}

/// @nodoc
abstract mixin class _$ScreenManagerStateCopyWith<$Res> implements $ScreenManagerStateCopyWith<$Res> {
  factory _$ScreenManagerStateCopyWith(_ScreenManagerState value, $Res Function(_ScreenManagerState) _then) = __$ScreenManagerStateCopyWithImpl;
@override @useResult
$Res call({
 ISet<ScreenId> screenIds
});




}
/// @nodoc
class __$ScreenManagerStateCopyWithImpl<$Res>
    implements _$ScreenManagerStateCopyWith<$Res> {
  __$ScreenManagerStateCopyWithImpl(this._self, this._then);

  final _ScreenManagerState _self;
  final $Res Function(_ScreenManagerState) _then;

/// Create a copy of ScreenManagerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? screenIds = null,}) {
  return _then(_ScreenManagerState(
screenIds: null == screenIds ? _self.screenIds : screenIds // ignore: cast_nullable_to_non_nullable
as ISet<ScreenId>,
  ));
}


}

// dart format on

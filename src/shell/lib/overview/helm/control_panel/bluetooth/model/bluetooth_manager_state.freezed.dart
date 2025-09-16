// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bluetooth_manager_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BluetoothManagerState {

 bool get powered; bool get discovering;
/// Create a copy of BluetoothManagerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BluetoothManagerStateCopyWith<BluetoothManagerState> get copyWith => _$BluetoothManagerStateCopyWithImpl<BluetoothManagerState>(this as BluetoothManagerState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BluetoothManagerState&&(identical(other.powered, powered) || other.powered == powered)&&(identical(other.discovering, discovering) || other.discovering == discovering));
}


@override
int get hashCode => Object.hash(runtimeType,powered,discovering);

@override
String toString() {
  return 'BluetoothManagerState(powered: $powered, discovering: $discovering)';
}


}

/// @nodoc
abstract mixin class $BluetoothManagerStateCopyWith<$Res>  {
  factory $BluetoothManagerStateCopyWith(BluetoothManagerState value, $Res Function(BluetoothManagerState) _then) = _$BluetoothManagerStateCopyWithImpl;
@useResult
$Res call({
 bool powered, bool discovering
});




}
/// @nodoc
class _$BluetoothManagerStateCopyWithImpl<$Res>
    implements $BluetoothManagerStateCopyWith<$Res> {
  _$BluetoothManagerStateCopyWithImpl(this._self, this._then);

  final BluetoothManagerState _self;
  final $Res Function(BluetoothManagerState) _then;

/// Create a copy of BluetoothManagerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? powered = null,Object? discovering = null,}) {
  return _then(_self.copyWith(
powered: null == powered ? _self.powered : powered // ignore: cast_nullable_to_non_nullable
as bool,discovering: null == discovering ? _self.discovering : discovering // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BluetoothManagerState].
extension BluetoothManagerStatePatterns on BluetoothManagerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BluetoothManagerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BluetoothManagerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BluetoothManagerState value)  $default,){
final _that = this;
switch (_that) {
case _BluetoothManagerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BluetoothManagerState value)?  $default,){
final _that = this;
switch (_that) {
case _BluetoothManagerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool powered,  bool discovering)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BluetoothManagerState() when $default != null:
return $default(_that.powered,_that.discovering);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool powered,  bool discovering)  $default,) {final _that = this;
switch (_that) {
case _BluetoothManagerState():
return $default(_that.powered,_that.discovering);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool powered,  bool discovering)?  $default,) {final _that = this;
switch (_that) {
case _BluetoothManagerState() when $default != null:
return $default(_that.powered,_that.discovering);case _:
  return null;

}
}

}

/// @nodoc


class _BluetoothManagerState implements BluetoothManagerState {
   _BluetoothManagerState({required this.powered, required this.discovering});
  

@override final  bool powered;
@override final  bool discovering;

/// Create a copy of BluetoothManagerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BluetoothManagerStateCopyWith<_BluetoothManagerState> get copyWith => __$BluetoothManagerStateCopyWithImpl<_BluetoothManagerState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BluetoothManagerState&&(identical(other.powered, powered) || other.powered == powered)&&(identical(other.discovering, discovering) || other.discovering == discovering));
}


@override
int get hashCode => Object.hash(runtimeType,powered,discovering);

@override
String toString() {
  return 'BluetoothManagerState(powered: $powered, discovering: $discovering)';
}


}

/// @nodoc
abstract mixin class _$BluetoothManagerStateCopyWith<$Res> implements $BluetoothManagerStateCopyWith<$Res> {
  factory _$BluetoothManagerStateCopyWith(_BluetoothManagerState value, $Res Function(_BluetoothManagerState) _then) = __$BluetoothManagerStateCopyWithImpl;
@override @useResult
$Res call({
 bool powered, bool discovering
});




}
/// @nodoc
class __$BluetoothManagerStateCopyWithImpl<$Res>
    implements _$BluetoothManagerStateCopyWith<$Res> {
  __$BluetoothManagerStateCopyWithImpl(this._self, this._then);

  final _BluetoothManagerState _self;
  final $Res Function(_BluetoothManagerState) _then;

/// Create a copy of BluetoothManagerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? powered = null,Object? discovering = null,}) {
  return _then(_BluetoothManagerState(
powered: null == powered ? _self.powered : powered // ignore: cast_nullable_to_non_nullable
as bool,discovering: null == discovering ? _self.discovering : discovering // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

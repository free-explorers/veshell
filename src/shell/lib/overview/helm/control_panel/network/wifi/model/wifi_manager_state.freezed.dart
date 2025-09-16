// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wifi_manager_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WifiManagerState {

 bool get isScanning;
/// Create a copy of WifiManagerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WifiManagerStateCopyWith<WifiManagerState> get copyWith => _$WifiManagerStateCopyWithImpl<WifiManagerState>(this as WifiManagerState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WifiManagerState&&(identical(other.isScanning, isScanning) || other.isScanning == isScanning));
}


@override
int get hashCode => Object.hash(runtimeType,isScanning);

@override
String toString() {
  return 'WifiManagerState(isScanning: $isScanning)';
}


}

/// @nodoc
abstract mixin class $WifiManagerStateCopyWith<$Res>  {
  factory $WifiManagerStateCopyWith(WifiManagerState value, $Res Function(WifiManagerState) _then) = _$WifiManagerStateCopyWithImpl;
@useResult
$Res call({
 bool isScanning
});




}
/// @nodoc
class _$WifiManagerStateCopyWithImpl<$Res>
    implements $WifiManagerStateCopyWith<$Res> {
  _$WifiManagerStateCopyWithImpl(this._self, this._then);

  final WifiManagerState _self;
  final $Res Function(WifiManagerState) _then;

/// Create a copy of WifiManagerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isScanning = null,}) {
  return _then(_self.copyWith(
isScanning: null == isScanning ? _self.isScanning : isScanning // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WifiManagerState].
extension WifiManagerStatePatterns on WifiManagerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WifiManagerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WifiManagerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WifiManagerState value)  $default,){
final _that = this;
switch (_that) {
case _WifiManagerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WifiManagerState value)?  $default,){
final _that = this;
switch (_that) {
case _WifiManagerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isScanning)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WifiManagerState() when $default != null:
return $default(_that.isScanning);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isScanning)  $default,) {final _that = this;
switch (_that) {
case _WifiManagerState():
return $default(_that.isScanning);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isScanning)?  $default,) {final _that = this;
switch (_that) {
case _WifiManagerState() when $default != null:
return $default(_that.isScanning);case _:
  return null;

}
}

}

/// @nodoc


class _WifiManagerState implements WifiManagerState {
   _WifiManagerState({required this.isScanning});
  

@override final  bool isScanning;

/// Create a copy of WifiManagerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WifiManagerStateCopyWith<_WifiManagerState> get copyWith => __$WifiManagerStateCopyWithImpl<_WifiManagerState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WifiManagerState&&(identical(other.isScanning, isScanning) || other.isScanning == isScanning));
}


@override
int get hashCode => Object.hash(runtimeType,isScanning);

@override
String toString() {
  return 'WifiManagerState(isScanning: $isScanning)';
}


}

/// @nodoc
abstract mixin class _$WifiManagerStateCopyWith<$Res> implements $WifiManagerStateCopyWith<$Res> {
  factory _$WifiManagerStateCopyWith(_WifiManagerState value, $Res Function(_WifiManagerState) _then) = __$WifiManagerStateCopyWithImpl;
@override @useResult
$Res call({
 bool isScanning
});




}
/// @nodoc
class __$WifiManagerStateCopyWithImpl<$Res>
    implements _$WifiManagerStateCopyWith<$Res> {
  __$WifiManagerStateCopyWithImpl(this._self, this._then);

  final _WifiManagerState _self;
  final $Res Function(_WifiManagerState) _then;

/// Create a copy of WifiManagerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isScanning = null,}) {
  return _then(_WifiManagerState(
isScanning: null == isScanning ? _self.isScanning : isScanning // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

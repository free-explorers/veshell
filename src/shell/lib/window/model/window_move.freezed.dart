// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'window_move.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WindowMoveState {

 bool get moving; Offset get startPosition; Offset get movedPosition; Offset get delta;
/// Create a copy of WindowMoveState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WindowMoveStateCopyWith<WindowMoveState> get copyWith => _$WindowMoveStateCopyWithImpl<WindowMoveState>(this as WindowMoveState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WindowMoveState&&(identical(other.moving, moving) || other.moving == moving)&&(identical(other.startPosition, startPosition) || other.startPosition == startPosition)&&(identical(other.movedPosition, movedPosition) || other.movedPosition == movedPosition)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,moving,startPosition,movedPosition,delta);

@override
String toString() {
  return 'WindowMoveState(moving: $moving, startPosition: $startPosition, movedPosition: $movedPosition, delta: $delta)';
}


}

/// @nodoc
abstract mixin class $WindowMoveStateCopyWith<$Res>  {
  factory $WindowMoveStateCopyWith(WindowMoveState value, $Res Function(WindowMoveState) _then) = _$WindowMoveStateCopyWithImpl;
@useResult
$Res call({
 bool moving, Offset startPosition, Offset movedPosition, Offset delta
});




}
/// @nodoc
class _$WindowMoveStateCopyWithImpl<$Res>
    implements $WindowMoveStateCopyWith<$Res> {
  _$WindowMoveStateCopyWithImpl(this._self, this._then);

  final WindowMoveState _self;
  final $Res Function(WindowMoveState) _then;

/// Create a copy of WindowMoveState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? moving = null,Object? startPosition = null,Object? movedPosition = null,Object? delta = null,}) {
  return _then(_self.copyWith(
moving: null == moving ? _self.moving : moving // ignore: cast_nullable_to_non_nullable
as bool,startPosition: null == startPosition ? _self.startPosition : startPosition // ignore: cast_nullable_to_non_nullable
as Offset,movedPosition: null == movedPosition ? _self.movedPosition : movedPosition // ignore: cast_nullable_to_non_nullable
as Offset,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as Offset,
  ));
}

}


/// Adds pattern-matching-related methods to [WindowMoveState].
extension WindowMoveStatePatterns on WindowMoveState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WindowMoveState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WindowMoveState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WindowMoveState value)  $default,){
final _that = this;
switch (_that) {
case _WindowMoveState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WindowMoveState value)?  $default,){
final _that = this;
switch (_that) {
case _WindowMoveState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool moving,  Offset startPosition,  Offset movedPosition,  Offset delta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WindowMoveState() when $default != null:
return $default(_that.moving,_that.startPosition,_that.movedPosition,_that.delta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool moving,  Offset startPosition,  Offset movedPosition,  Offset delta)  $default,) {final _that = this;
switch (_that) {
case _WindowMoveState():
return $default(_that.moving,_that.startPosition,_that.movedPosition,_that.delta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool moving,  Offset startPosition,  Offset movedPosition,  Offset delta)?  $default,) {final _that = this;
switch (_that) {
case _WindowMoveState() when $default != null:
return $default(_that.moving,_that.startPosition,_that.movedPosition,_that.delta);case _:
  return null;

}
}

}

/// @nodoc


class _WindowMoveState implements WindowMoveState {
  const _WindowMoveState({required this.moving, required this.startPosition, required this.movedPosition, required this.delta});
  

@override final  bool moving;
@override final  Offset startPosition;
@override final  Offset movedPosition;
@override final  Offset delta;

/// Create a copy of WindowMoveState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WindowMoveStateCopyWith<_WindowMoveState> get copyWith => __$WindowMoveStateCopyWithImpl<_WindowMoveState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WindowMoveState&&(identical(other.moving, moving) || other.moving == moving)&&(identical(other.startPosition, startPosition) || other.startPosition == startPosition)&&(identical(other.movedPosition, movedPosition) || other.movedPosition == movedPosition)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,moving,startPosition,movedPosition,delta);

@override
String toString() {
  return 'WindowMoveState(moving: $moving, startPosition: $startPosition, movedPosition: $movedPosition, delta: $delta)';
}


}

/// @nodoc
abstract mixin class _$WindowMoveStateCopyWith<$Res> implements $WindowMoveStateCopyWith<$Res> {
  factory _$WindowMoveStateCopyWith(_WindowMoveState value, $Res Function(_WindowMoveState) _then) = __$WindowMoveStateCopyWithImpl;
@override @useResult
$Res call({
 bool moving, Offset startPosition, Offset movedPosition, Offset delta
});




}
/// @nodoc
class __$WindowMoveStateCopyWithImpl<$Res>
    implements _$WindowMoveStateCopyWith<$Res> {
  __$WindowMoveStateCopyWithImpl(this._self, this._then);

  final _WindowMoveState _self;
  final $Res Function(_WindowMoveState) _then;

/// Create a copy of WindowMoveState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? moving = null,Object? startPosition = null,Object? movedPosition = null,Object? delta = null,}) {
  return _then(_WindowMoveState(
moving: null == moving ? _self.moving : moving // ignore: cast_nullable_to_non_nullable
as bool,startPosition: null == startPosition ? _self.startPosition : startPosition // ignore: cast_nullable_to_non_nullable
as Offset,movedPosition: null == movedPosition ? _self.movedPosition : movedPosition // ignore: cast_nullable_to_non_nullable
as Offset,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as Offset,
  ));
}


}

// dart format on

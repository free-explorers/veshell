// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gesture_swipe_begin.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GestureSwipeBeginMessage {

 int get time; int get fingers;
/// Create a copy of GestureSwipeBeginMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GestureSwipeBeginMessageCopyWith<GestureSwipeBeginMessage> get copyWith => _$GestureSwipeBeginMessageCopyWithImpl<GestureSwipeBeginMessage>(this as GestureSwipeBeginMessage, _$identity);

  /// Serializes this GestureSwipeBeginMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GestureSwipeBeginMessage&&(identical(other.time, time) || other.time == time)&&(identical(other.fingers, fingers) || other.fingers == fingers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,time,fingers);

@override
String toString() {
  return 'GestureSwipeBeginMessage(time: $time, fingers: $fingers)';
}


}

/// @nodoc
abstract mixin class $GestureSwipeBeginMessageCopyWith<$Res>  {
  factory $GestureSwipeBeginMessageCopyWith(GestureSwipeBeginMessage value, $Res Function(GestureSwipeBeginMessage) _then) = _$GestureSwipeBeginMessageCopyWithImpl;
@useResult
$Res call({
 int time, int fingers
});




}
/// @nodoc
class _$GestureSwipeBeginMessageCopyWithImpl<$Res>
    implements $GestureSwipeBeginMessageCopyWith<$Res> {
  _$GestureSwipeBeginMessageCopyWithImpl(this._self, this._then);

  final GestureSwipeBeginMessage _self;
  final $Res Function(GestureSwipeBeginMessage) _then;

/// Create a copy of GestureSwipeBeginMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? time = null,Object? fingers = null,}) {
  return _then(_self.copyWith(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as int,fingers: null == fingers ? _self.fingers : fingers // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GestureSwipeBeginMessage].
extension GestureSwipeBeginMessagePatterns on GestureSwipeBeginMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GestureSwipeBeginMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GestureSwipeBeginMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GestureSwipeBeginMessage value)  $default,){
final _that = this;
switch (_that) {
case _GestureSwipeBeginMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GestureSwipeBeginMessage value)?  $default,){
final _that = this;
switch (_that) {
case _GestureSwipeBeginMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int time,  int fingers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GestureSwipeBeginMessage() when $default != null:
return $default(_that.time,_that.fingers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int time,  int fingers)  $default,) {final _that = this;
switch (_that) {
case _GestureSwipeBeginMessage():
return $default(_that.time,_that.fingers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int time,  int fingers)?  $default,) {final _that = this;
switch (_that) {
case _GestureSwipeBeginMessage() when $default != null:
return $default(_that.time,_that.fingers);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GestureSwipeBeginMessage implements GestureSwipeBeginMessage {
   _GestureSwipeBeginMessage({required this.time, required this.fingers});
  factory _GestureSwipeBeginMessage.fromJson(Map<String, dynamic> json) => _$GestureSwipeBeginMessageFromJson(json);

@override final  int time;
@override final  int fingers;

/// Create a copy of GestureSwipeBeginMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GestureSwipeBeginMessageCopyWith<_GestureSwipeBeginMessage> get copyWith => __$GestureSwipeBeginMessageCopyWithImpl<_GestureSwipeBeginMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GestureSwipeBeginMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GestureSwipeBeginMessage&&(identical(other.time, time) || other.time == time)&&(identical(other.fingers, fingers) || other.fingers == fingers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,time,fingers);

@override
String toString() {
  return 'GestureSwipeBeginMessage(time: $time, fingers: $fingers)';
}


}

/// @nodoc
abstract mixin class _$GestureSwipeBeginMessageCopyWith<$Res> implements $GestureSwipeBeginMessageCopyWith<$Res> {
  factory _$GestureSwipeBeginMessageCopyWith(_GestureSwipeBeginMessage value, $Res Function(_GestureSwipeBeginMessage) _then) = __$GestureSwipeBeginMessageCopyWithImpl;
@override @useResult
$Res call({
 int time, int fingers
});




}
/// @nodoc
class __$GestureSwipeBeginMessageCopyWithImpl<$Res>
    implements _$GestureSwipeBeginMessageCopyWith<$Res> {
  __$GestureSwipeBeginMessageCopyWithImpl(this._self, this._then);

  final _GestureSwipeBeginMessage _self;
  final $Res Function(_GestureSwipeBeginMessage) _then;

/// Create a copy of GestureSwipeBeginMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? time = null,Object? fingers = null,}) {
  return _then(_GestureSwipeBeginMessage(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as int,fingers: null == fingers ? _self.fingers : fingers // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

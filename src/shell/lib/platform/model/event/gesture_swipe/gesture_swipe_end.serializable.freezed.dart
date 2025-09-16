// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gesture_swipe_end.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GestureSwipeEndMessage {

 int get time; int get fingers; bool get cancelled;
/// Create a copy of GestureSwipeEndMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GestureSwipeEndMessageCopyWith<GestureSwipeEndMessage> get copyWith => _$GestureSwipeEndMessageCopyWithImpl<GestureSwipeEndMessage>(this as GestureSwipeEndMessage, _$identity);

  /// Serializes this GestureSwipeEndMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GestureSwipeEndMessage&&(identical(other.time, time) || other.time == time)&&(identical(other.fingers, fingers) || other.fingers == fingers)&&(identical(other.cancelled, cancelled) || other.cancelled == cancelled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,time,fingers,cancelled);

@override
String toString() {
  return 'GestureSwipeEndMessage(time: $time, fingers: $fingers, cancelled: $cancelled)';
}


}

/// @nodoc
abstract mixin class $GestureSwipeEndMessageCopyWith<$Res>  {
  factory $GestureSwipeEndMessageCopyWith(GestureSwipeEndMessage value, $Res Function(GestureSwipeEndMessage) _then) = _$GestureSwipeEndMessageCopyWithImpl;
@useResult
$Res call({
 int time, int fingers, bool cancelled
});




}
/// @nodoc
class _$GestureSwipeEndMessageCopyWithImpl<$Res>
    implements $GestureSwipeEndMessageCopyWith<$Res> {
  _$GestureSwipeEndMessageCopyWithImpl(this._self, this._then);

  final GestureSwipeEndMessage _self;
  final $Res Function(GestureSwipeEndMessage) _then;

/// Create a copy of GestureSwipeEndMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? time = null,Object? fingers = null,Object? cancelled = null,}) {
  return _then(_self.copyWith(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as int,fingers: null == fingers ? _self.fingers : fingers // ignore: cast_nullable_to_non_nullable
as int,cancelled: null == cancelled ? _self.cancelled : cancelled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [GestureSwipeEndMessage].
extension GestureSwipeEndMessagePatterns on GestureSwipeEndMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GestureSwipeEndMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GestureSwipeEndMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GestureSwipeEndMessage value)  $default,){
final _that = this;
switch (_that) {
case _GestureSwipeEndMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GestureSwipeEndMessage value)?  $default,){
final _that = this;
switch (_that) {
case _GestureSwipeEndMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int time,  int fingers,  bool cancelled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GestureSwipeEndMessage() when $default != null:
return $default(_that.time,_that.fingers,_that.cancelled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int time,  int fingers,  bool cancelled)  $default,) {final _that = this;
switch (_that) {
case _GestureSwipeEndMessage():
return $default(_that.time,_that.fingers,_that.cancelled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int time,  int fingers,  bool cancelled)?  $default,) {final _that = this;
switch (_that) {
case _GestureSwipeEndMessage() when $default != null:
return $default(_that.time,_that.fingers,_that.cancelled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GestureSwipeEndMessage implements GestureSwipeEndMessage {
   _GestureSwipeEndMessage({required this.time, required this.fingers, required this.cancelled});
  factory _GestureSwipeEndMessage.fromJson(Map<String, dynamic> json) => _$GestureSwipeEndMessageFromJson(json);

@override final  int time;
@override final  int fingers;
@override final  bool cancelled;

/// Create a copy of GestureSwipeEndMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GestureSwipeEndMessageCopyWith<_GestureSwipeEndMessage> get copyWith => __$GestureSwipeEndMessageCopyWithImpl<_GestureSwipeEndMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GestureSwipeEndMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GestureSwipeEndMessage&&(identical(other.time, time) || other.time == time)&&(identical(other.fingers, fingers) || other.fingers == fingers)&&(identical(other.cancelled, cancelled) || other.cancelled == cancelled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,time,fingers,cancelled);

@override
String toString() {
  return 'GestureSwipeEndMessage(time: $time, fingers: $fingers, cancelled: $cancelled)';
}


}

/// @nodoc
abstract mixin class _$GestureSwipeEndMessageCopyWith<$Res> implements $GestureSwipeEndMessageCopyWith<$Res> {
  factory _$GestureSwipeEndMessageCopyWith(_GestureSwipeEndMessage value, $Res Function(_GestureSwipeEndMessage) _then) = __$GestureSwipeEndMessageCopyWithImpl;
@override @useResult
$Res call({
 int time, int fingers, bool cancelled
});




}
/// @nodoc
class __$GestureSwipeEndMessageCopyWithImpl<$Res>
    implements _$GestureSwipeEndMessageCopyWith<$Res> {
  __$GestureSwipeEndMessageCopyWithImpl(this._self, this._then);

  final _GestureSwipeEndMessage _self;
  final $Res Function(_GestureSwipeEndMessage) _then;

/// Create a copy of GestureSwipeEndMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? time = null,Object? fingers = null,Object? cancelled = null,}) {
  return _then(_GestureSwipeEndMessage(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as int,fingers: null == fingers ? _self.fingers : fingers // ignore: cast_nullable_to_non_nullable
as int,cancelled: null == cancelled ? _self.cancelled : cancelled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gesture_swipe_update.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GestureSwipeUpdateMessage {

 int get time; int get fingers; double get deltaX; double get deltaY;
/// Create a copy of GestureSwipeUpdateMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GestureSwipeUpdateMessageCopyWith<GestureSwipeUpdateMessage> get copyWith => _$GestureSwipeUpdateMessageCopyWithImpl<GestureSwipeUpdateMessage>(this as GestureSwipeUpdateMessage, _$identity);

  /// Serializes this GestureSwipeUpdateMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GestureSwipeUpdateMessage&&(identical(other.time, time) || other.time == time)&&(identical(other.fingers, fingers) || other.fingers == fingers)&&(identical(other.deltaX, deltaX) || other.deltaX == deltaX)&&(identical(other.deltaY, deltaY) || other.deltaY == deltaY));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,time,fingers,deltaX,deltaY);

@override
String toString() {
  return 'GestureSwipeUpdateMessage(time: $time, fingers: $fingers, deltaX: $deltaX, deltaY: $deltaY)';
}


}

/// @nodoc
abstract mixin class $GestureSwipeUpdateMessageCopyWith<$Res>  {
  factory $GestureSwipeUpdateMessageCopyWith(GestureSwipeUpdateMessage value, $Res Function(GestureSwipeUpdateMessage) _then) = _$GestureSwipeUpdateMessageCopyWithImpl;
@useResult
$Res call({
 int time, int fingers, double deltaX, double deltaY
});




}
/// @nodoc
class _$GestureSwipeUpdateMessageCopyWithImpl<$Res>
    implements $GestureSwipeUpdateMessageCopyWith<$Res> {
  _$GestureSwipeUpdateMessageCopyWithImpl(this._self, this._then);

  final GestureSwipeUpdateMessage _self;
  final $Res Function(GestureSwipeUpdateMessage) _then;

/// Create a copy of GestureSwipeUpdateMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? time = null,Object? fingers = null,Object? deltaX = null,Object? deltaY = null,}) {
  return _then(_self.copyWith(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as int,fingers: null == fingers ? _self.fingers : fingers // ignore: cast_nullable_to_non_nullable
as int,deltaX: null == deltaX ? _self.deltaX : deltaX // ignore: cast_nullable_to_non_nullable
as double,deltaY: null == deltaY ? _self.deltaY : deltaY // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [GestureSwipeUpdateMessage].
extension GestureSwipeUpdateMessagePatterns on GestureSwipeUpdateMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GestureSwipeUpdateMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GestureSwipeUpdateMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GestureSwipeUpdateMessage value)  $default,){
final _that = this;
switch (_that) {
case _GestureSwipeUpdateMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GestureSwipeUpdateMessage value)?  $default,){
final _that = this;
switch (_that) {
case _GestureSwipeUpdateMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int time,  int fingers,  double deltaX,  double deltaY)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GestureSwipeUpdateMessage() when $default != null:
return $default(_that.time,_that.fingers,_that.deltaX,_that.deltaY);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int time,  int fingers,  double deltaX,  double deltaY)  $default,) {final _that = this;
switch (_that) {
case _GestureSwipeUpdateMessage():
return $default(_that.time,_that.fingers,_that.deltaX,_that.deltaY);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int time,  int fingers,  double deltaX,  double deltaY)?  $default,) {final _that = this;
switch (_that) {
case _GestureSwipeUpdateMessage() when $default != null:
return $default(_that.time,_that.fingers,_that.deltaX,_that.deltaY);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GestureSwipeUpdateMessage implements GestureSwipeUpdateMessage {
   _GestureSwipeUpdateMessage({required this.time, required this.fingers, required this.deltaX, required this.deltaY});
  factory _GestureSwipeUpdateMessage.fromJson(Map<String, dynamic> json) => _$GestureSwipeUpdateMessageFromJson(json);

@override final  int time;
@override final  int fingers;
@override final  double deltaX;
@override final  double deltaY;

/// Create a copy of GestureSwipeUpdateMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GestureSwipeUpdateMessageCopyWith<_GestureSwipeUpdateMessage> get copyWith => __$GestureSwipeUpdateMessageCopyWithImpl<_GestureSwipeUpdateMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GestureSwipeUpdateMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GestureSwipeUpdateMessage&&(identical(other.time, time) || other.time == time)&&(identical(other.fingers, fingers) || other.fingers == fingers)&&(identical(other.deltaX, deltaX) || other.deltaX == deltaX)&&(identical(other.deltaY, deltaY) || other.deltaY == deltaY));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,time,fingers,deltaX,deltaY);

@override
String toString() {
  return 'GestureSwipeUpdateMessage(time: $time, fingers: $fingers, deltaX: $deltaX, deltaY: $deltaY)';
}


}

/// @nodoc
abstract mixin class _$GestureSwipeUpdateMessageCopyWith<$Res> implements $GestureSwipeUpdateMessageCopyWith<$Res> {
  factory _$GestureSwipeUpdateMessageCopyWith(_GestureSwipeUpdateMessage value, $Res Function(_GestureSwipeUpdateMessage) _then) = __$GestureSwipeUpdateMessageCopyWithImpl;
@override @useResult
$Res call({
 int time, int fingers, double deltaX, double deltaY
});




}
/// @nodoc
class __$GestureSwipeUpdateMessageCopyWithImpl<$Res>
    implements _$GestureSwipeUpdateMessageCopyWith<$Res> {
  __$GestureSwipeUpdateMessageCopyWithImpl(this._self, this._then);

  final _GestureSwipeUpdateMessage _self;
  final $Res Function(_GestureSwipeUpdateMessage) _then;

/// Create a copy of GestureSwipeUpdateMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? time = null,Object? fingers = null,Object? deltaX = null,Object? deltaY = null,}) {
  return _then(_GestureSwipeUpdateMessage(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as int,fingers: null == fingers ? _self.fingers : fingers // ignore: cast_nullable_to_non_nullable
as int,deltaX: null == deltaX ? _self.deltaX : deltaX // ignore: cast_nullable_to_non_nullable
as double,deltaY: null == deltaY ? _self.deltaY : deltaY // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on

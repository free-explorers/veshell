// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'touch.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TouchDownMessage {

 SurfaceId get surfaceId; int get touchId;
/// Create a copy of TouchDownMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TouchDownMessageCopyWith<TouchDownMessage> get copyWith => _$TouchDownMessageCopyWithImpl<TouchDownMessage>(this as TouchDownMessage, _$identity);

  /// Serializes this TouchDownMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TouchDownMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.touchId, touchId) || other.touchId == touchId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId,touchId);

@override
String toString() {
  return 'TouchDownMessage(surfaceId: $surfaceId, touchId: $touchId)';
}


}

/// @nodoc
abstract mixin class $TouchDownMessageCopyWith<$Res>  {
  factory $TouchDownMessageCopyWith(TouchDownMessage value, $Res Function(TouchDownMessage) _then) = _$TouchDownMessageCopyWithImpl;
@useResult
$Res call({
 SurfaceId surfaceId, int touchId
});




}
/// @nodoc
class _$TouchDownMessageCopyWithImpl<$Res>
    implements $TouchDownMessageCopyWith<$Res> {
  _$TouchDownMessageCopyWithImpl(this._self, this._then);

  final TouchDownMessage _self;
  final $Res Function(TouchDownMessage) _then;

/// Create a copy of TouchDownMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? surfaceId = null,Object? touchId = null,}) {
  return _then(_self.copyWith(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,touchId: null == touchId ? _self.touchId : touchId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TouchDownMessage].
extension TouchDownMessagePatterns on TouchDownMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TouchDownMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TouchDownMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TouchDownMessage value)  $default,){
final _that = this;
switch (_that) {
case _TouchDownMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TouchDownMessage value)?  $default,){
final _that = this;
switch (_that) {
case _TouchDownMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SurfaceId surfaceId,  int touchId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TouchDownMessage() when $default != null:
return $default(_that.surfaceId,_that.touchId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SurfaceId surfaceId,  int touchId)  $default,) {final _that = this;
switch (_that) {
case _TouchDownMessage():
return $default(_that.surfaceId,_that.touchId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SurfaceId surfaceId,  int touchId)?  $default,) {final _that = this;
switch (_that) {
case _TouchDownMessage() when $default != null:
return $default(_that.surfaceId,_that.touchId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TouchDownMessage implements TouchDownMessage {
   _TouchDownMessage({required this.surfaceId, required this.touchId});
  factory _TouchDownMessage.fromJson(Map<String, dynamic> json) => _$TouchDownMessageFromJson(json);

@override final  SurfaceId surfaceId;
@override final  int touchId;

/// Create a copy of TouchDownMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TouchDownMessageCopyWith<_TouchDownMessage> get copyWith => __$TouchDownMessageCopyWithImpl<_TouchDownMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TouchDownMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TouchDownMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.touchId, touchId) || other.touchId == touchId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId,touchId);

@override
String toString() {
  return 'TouchDownMessage(surfaceId: $surfaceId, touchId: $touchId)';
}


}

/// @nodoc
abstract mixin class _$TouchDownMessageCopyWith<$Res> implements $TouchDownMessageCopyWith<$Res> {
  factory _$TouchDownMessageCopyWith(_TouchDownMessage value, $Res Function(_TouchDownMessage) _then) = __$TouchDownMessageCopyWithImpl;
@override @useResult
$Res call({
 SurfaceId surfaceId, int touchId
});




}
/// @nodoc
class __$TouchDownMessageCopyWithImpl<$Res>
    implements _$TouchDownMessageCopyWith<$Res> {
  __$TouchDownMessageCopyWithImpl(this._self, this._then);

  final _TouchDownMessage _self;
  final $Res Function(_TouchDownMessage) _then;

/// Create a copy of TouchDownMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surfaceId = null,Object? touchId = null,}) {
  return _then(_TouchDownMessage(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,touchId: null == touchId ? _self.touchId : touchId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TouchMotionMessage {

 int get touchId;
/// Create a copy of TouchMotionMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TouchMotionMessageCopyWith<TouchMotionMessage> get copyWith => _$TouchMotionMessageCopyWithImpl<TouchMotionMessage>(this as TouchMotionMessage, _$identity);

  /// Serializes this TouchMotionMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TouchMotionMessage&&(identical(other.touchId, touchId) || other.touchId == touchId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,touchId);

@override
String toString() {
  return 'TouchMotionMessage(touchId: $touchId)';
}


}

/// @nodoc
abstract mixin class $TouchMotionMessageCopyWith<$Res>  {
  factory $TouchMotionMessageCopyWith(TouchMotionMessage value, $Res Function(TouchMotionMessage) _then) = _$TouchMotionMessageCopyWithImpl;
@useResult
$Res call({
 int touchId
});




}
/// @nodoc
class _$TouchMotionMessageCopyWithImpl<$Res>
    implements $TouchMotionMessageCopyWith<$Res> {
  _$TouchMotionMessageCopyWithImpl(this._self, this._then);

  final TouchMotionMessage _self;
  final $Res Function(TouchMotionMessage) _then;

/// Create a copy of TouchMotionMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? touchId = null,}) {
  return _then(_self.copyWith(
touchId: null == touchId ? _self.touchId : touchId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TouchMotionMessage].
extension TouchMotionMessagePatterns on TouchMotionMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TouchMotionMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TouchMotionMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TouchMotionMessage value)  $default,){
final _that = this;
switch (_that) {
case _TouchMotionMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TouchMotionMessage value)?  $default,){
final _that = this;
switch (_that) {
case _TouchMotionMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int touchId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TouchMotionMessage() when $default != null:
return $default(_that.touchId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int touchId)  $default,) {final _that = this;
switch (_that) {
case _TouchMotionMessage():
return $default(_that.touchId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int touchId)?  $default,) {final _that = this;
switch (_that) {
case _TouchMotionMessage() when $default != null:
return $default(_that.touchId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TouchMotionMessage implements TouchMotionMessage {
   _TouchMotionMessage({required this.touchId});
  factory _TouchMotionMessage.fromJson(Map<String, dynamic> json) => _$TouchMotionMessageFromJson(json);

@override final  int touchId;

/// Create a copy of TouchMotionMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TouchMotionMessageCopyWith<_TouchMotionMessage> get copyWith => __$TouchMotionMessageCopyWithImpl<_TouchMotionMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TouchMotionMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TouchMotionMessage&&(identical(other.touchId, touchId) || other.touchId == touchId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,touchId);

@override
String toString() {
  return 'TouchMotionMessage(touchId: $touchId)';
}


}

/// @nodoc
abstract mixin class _$TouchMotionMessageCopyWith<$Res> implements $TouchMotionMessageCopyWith<$Res> {
  factory _$TouchMotionMessageCopyWith(_TouchMotionMessage value, $Res Function(_TouchMotionMessage) _then) = __$TouchMotionMessageCopyWithImpl;
@override @useResult
$Res call({
 int touchId
});




}
/// @nodoc
class __$TouchMotionMessageCopyWithImpl<$Res>
    implements _$TouchMotionMessageCopyWith<$Res> {
  __$TouchMotionMessageCopyWithImpl(this._self, this._then);

  final _TouchMotionMessage _self;
  final $Res Function(_TouchMotionMessage) _then;

/// Create a copy of TouchMotionMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? touchId = null,}) {
  return _then(_TouchMotionMessage(
touchId: null == touchId ? _self.touchId : touchId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TouchIdMessage {

 int get touchId;
/// Create a copy of TouchIdMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TouchIdMessageCopyWith<TouchIdMessage> get copyWith => _$TouchIdMessageCopyWithImpl<TouchIdMessage>(this as TouchIdMessage, _$identity);

  /// Serializes this TouchIdMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TouchIdMessage&&(identical(other.touchId, touchId) || other.touchId == touchId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,touchId);

@override
String toString() {
  return 'TouchIdMessage(touchId: $touchId)';
}


}

/// @nodoc
abstract mixin class $TouchIdMessageCopyWith<$Res>  {
  factory $TouchIdMessageCopyWith(TouchIdMessage value, $Res Function(TouchIdMessage) _then) = _$TouchIdMessageCopyWithImpl;
@useResult
$Res call({
 int touchId
});




}
/// @nodoc
class _$TouchIdMessageCopyWithImpl<$Res>
    implements $TouchIdMessageCopyWith<$Res> {
  _$TouchIdMessageCopyWithImpl(this._self, this._then);

  final TouchIdMessage _self;
  final $Res Function(TouchIdMessage) _then;

/// Create a copy of TouchIdMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? touchId = null,}) {
  return _then(_self.copyWith(
touchId: null == touchId ? _self.touchId : touchId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TouchIdMessage].
extension TouchIdMessagePatterns on TouchIdMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TouchIdMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TouchIdMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TouchIdMessage value)  $default,){
final _that = this;
switch (_that) {
case _TouchIdMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TouchIdMessage value)?  $default,){
final _that = this;
switch (_that) {
case _TouchIdMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int touchId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TouchIdMessage() when $default != null:
return $default(_that.touchId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int touchId)  $default,) {final _that = this;
switch (_that) {
case _TouchIdMessage():
return $default(_that.touchId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int touchId)?  $default,) {final _that = this;
switch (_that) {
case _TouchIdMessage() when $default != null:
return $default(_that.touchId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TouchIdMessage implements TouchIdMessage {
   _TouchIdMessage({required this.touchId});
  factory _TouchIdMessage.fromJson(Map<String, dynamic> json) => _$TouchIdMessageFromJson(json);

@override final  int touchId;

/// Create a copy of TouchIdMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TouchIdMessageCopyWith<_TouchIdMessage> get copyWith => __$TouchIdMessageCopyWithImpl<_TouchIdMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TouchIdMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TouchIdMessage&&(identical(other.touchId, touchId) || other.touchId == touchId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,touchId);

@override
String toString() {
  return 'TouchIdMessage(touchId: $touchId)';
}


}

/// @nodoc
abstract mixin class _$TouchIdMessageCopyWith<$Res> implements $TouchIdMessageCopyWith<$Res> {
  factory _$TouchIdMessageCopyWith(_TouchIdMessage value, $Res Function(_TouchIdMessage) _then) = __$TouchIdMessageCopyWithImpl;
@override @useResult
$Res call({
 int touchId
});




}
/// @nodoc
class __$TouchIdMessageCopyWithImpl<$Res>
    implements _$TouchIdMessageCopyWith<$Res> {
  __$TouchIdMessageCopyWithImpl(this._self, this._then);

  final _TouchIdMessage _self;
  final $Res Function(_TouchIdMessage) _then;

/// Create a copy of TouchIdMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? touchId = null,}) {
  return _then(_TouchIdMessage(
touchId: null == touchId ? _self.touchId : touchId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

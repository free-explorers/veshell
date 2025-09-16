// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'resize_window.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ResizeWindowMessage {

 MetaWindowId get metaWindowId; int get width; int get height;
/// Create a copy of ResizeWindowMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResizeWindowMessageCopyWith<ResizeWindowMessage> get copyWith => _$ResizeWindowMessageCopyWithImpl<ResizeWindowMessage>(this as ResizeWindowMessage, _$identity);

  /// Serializes this ResizeWindowMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResizeWindowMessage&&(identical(other.metaWindowId, metaWindowId) || other.metaWindowId == metaWindowId)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,metaWindowId,width,height);

@override
String toString() {
  return 'ResizeWindowMessage(metaWindowId: $metaWindowId, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $ResizeWindowMessageCopyWith<$Res>  {
  factory $ResizeWindowMessageCopyWith(ResizeWindowMessage value, $Res Function(ResizeWindowMessage) _then) = _$ResizeWindowMessageCopyWithImpl;
@useResult
$Res call({
 MetaWindowId metaWindowId, int width, int height
});




}
/// @nodoc
class _$ResizeWindowMessageCopyWithImpl<$Res>
    implements $ResizeWindowMessageCopyWith<$Res> {
  _$ResizeWindowMessageCopyWithImpl(this._self, this._then);

  final ResizeWindowMessage _self;
  final $Res Function(ResizeWindowMessage) _then;

/// Create a copy of ResizeWindowMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? metaWindowId = null,Object? width = null,Object? height = null,}) {
  return _then(_self.copyWith(
metaWindowId: null == metaWindowId ? _self.metaWindowId : metaWindowId // ignore: cast_nullable_to_non_nullable
as MetaWindowId,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ResizeWindowMessage].
extension ResizeWindowMessagePatterns on ResizeWindowMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResizeWindowMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResizeWindowMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResizeWindowMessage value)  $default,){
final _that = this;
switch (_that) {
case _ResizeWindowMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResizeWindowMessage value)?  $default,){
final _that = this;
switch (_that) {
case _ResizeWindowMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MetaWindowId metaWindowId,  int width,  int height)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResizeWindowMessage() when $default != null:
return $default(_that.metaWindowId,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MetaWindowId metaWindowId,  int width,  int height)  $default,) {final _that = this;
switch (_that) {
case _ResizeWindowMessage():
return $default(_that.metaWindowId,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MetaWindowId metaWindowId,  int width,  int height)?  $default,) {final _that = this;
switch (_that) {
case _ResizeWindowMessage() when $default != null:
return $default(_that.metaWindowId,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ResizeWindowMessage implements ResizeWindowMessage {
   _ResizeWindowMessage({required this.metaWindowId, required this.width, required this.height});
  factory _ResizeWindowMessage.fromJson(Map<String, dynamic> json) => _$ResizeWindowMessageFromJson(json);

@override final  MetaWindowId metaWindowId;
@override final  int width;
@override final  int height;

/// Create a copy of ResizeWindowMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResizeWindowMessageCopyWith<_ResizeWindowMessage> get copyWith => __$ResizeWindowMessageCopyWithImpl<_ResizeWindowMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ResizeWindowMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResizeWindowMessage&&(identical(other.metaWindowId, metaWindowId) || other.metaWindowId == metaWindowId)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,metaWindowId,width,height);

@override
String toString() {
  return 'ResizeWindowMessage(metaWindowId: $metaWindowId, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$ResizeWindowMessageCopyWith<$Res> implements $ResizeWindowMessageCopyWith<$Res> {
  factory _$ResizeWindowMessageCopyWith(_ResizeWindowMessage value, $Res Function(_ResizeWindowMessage) _then) = __$ResizeWindowMessageCopyWithImpl;
@override @useResult
$Res call({
 MetaWindowId metaWindowId, int width, int height
});




}
/// @nodoc
class __$ResizeWindowMessageCopyWithImpl<$Res>
    implements _$ResizeWindowMessageCopyWith<$Res> {
  __$ResizeWindowMessageCopyWithImpl(this._self, this._then);

  final _ResizeWindowMessage _self;
  final $Res Function(_ResizeWindowMessage) _then;

/// Create a copy of ResizeWindowMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? metaWindowId = null,Object? width = null,Object? height = null,}) {
  return _then(_ResizeWindowMessage(
metaWindowId: null == metaWindowId ? _self.metaWindowId : metaWindowId // ignore: cast_nullable_to_non_nullable
as MetaWindowId,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

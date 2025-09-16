// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'unregister_view_texture.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UnregisterViewTextureMessage {

 int get textureId;
/// Create a copy of UnregisterViewTextureMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnregisterViewTextureMessageCopyWith<UnregisterViewTextureMessage> get copyWith => _$UnregisterViewTextureMessageCopyWithImpl<UnregisterViewTextureMessage>(this as UnregisterViewTextureMessage, _$identity);

  /// Serializes this UnregisterViewTextureMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnregisterViewTextureMessage&&(identical(other.textureId, textureId) || other.textureId == textureId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,textureId);

@override
String toString() {
  return 'UnregisterViewTextureMessage(textureId: $textureId)';
}


}

/// @nodoc
abstract mixin class $UnregisterViewTextureMessageCopyWith<$Res>  {
  factory $UnregisterViewTextureMessageCopyWith(UnregisterViewTextureMessage value, $Res Function(UnregisterViewTextureMessage) _then) = _$UnregisterViewTextureMessageCopyWithImpl;
@useResult
$Res call({
 int textureId
});




}
/// @nodoc
class _$UnregisterViewTextureMessageCopyWithImpl<$Res>
    implements $UnregisterViewTextureMessageCopyWith<$Res> {
  _$UnregisterViewTextureMessageCopyWithImpl(this._self, this._then);

  final UnregisterViewTextureMessage _self;
  final $Res Function(UnregisterViewTextureMessage) _then;

/// Create a copy of UnregisterViewTextureMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? textureId = null,}) {
  return _then(_self.copyWith(
textureId: null == textureId ? _self.textureId : textureId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UnregisterViewTextureMessage].
extension UnregisterViewTextureMessagePatterns on UnregisterViewTextureMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UnregisterViewTextureMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UnregisterViewTextureMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UnregisterViewTextureMessage value)  $default,){
final _that = this;
switch (_that) {
case _UnregisterViewTextureMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UnregisterViewTextureMessage value)?  $default,){
final _that = this;
switch (_that) {
case _UnregisterViewTextureMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int textureId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UnregisterViewTextureMessage() when $default != null:
return $default(_that.textureId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int textureId)  $default,) {final _that = this;
switch (_that) {
case _UnregisterViewTextureMessage():
return $default(_that.textureId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int textureId)?  $default,) {final _that = this;
switch (_that) {
case _UnregisterViewTextureMessage() when $default != null:
return $default(_that.textureId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UnregisterViewTextureMessage implements UnregisterViewTextureMessage {
   _UnregisterViewTextureMessage({required this.textureId});
  factory _UnregisterViewTextureMessage.fromJson(Map<String, dynamic> json) => _$UnregisterViewTextureMessageFromJson(json);

@override final  int textureId;

/// Create a copy of UnregisterViewTextureMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnregisterViewTextureMessageCopyWith<_UnregisterViewTextureMessage> get copyWith => __$UnregisterViewTextureMessageCopyWithImpl<_UnregisterViewTextureMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UnregisterViewTextureMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UnregisterViewTextureMessage&&(identical(other.textureId, textureId) || other.textureId == textureId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,textureId);

@override
String toString() {
  return 'UnregisterViewTextureMessage(textureId: $textureId)';
}


}

/// @nodoc
abstract mixin class _$UnregisterViewTextureMessageCopyWith<$Res> implements $UnregisterViewTextureMessageCopyWith<$Res> {
  factory _$UnregisterViewTextureMessageCopyWith(_UnregisterViewTextureMessage value, $Res Function(_UnregisterViewTextureMessage) _then) = __$UnregisterViewTextureMessageCopyWithImpl;
@override @useResult
$Res call({
 int textureId
});




}
/// @nodoc
class __$UnregisterViewTextureMessageCopyWithImpl<$Res>
    implements _$UnregisterViewTextureMessageCopyWith<$Res> {
  __$UnregisterViewTextureMessageCopyWithImpl(this._self, this._then);

  final _UnregisterViewTextureMessage _self;
  final $Res Function(_UnregisterViewTextureMessage) _then;

/// Create a copy of UnregisterViewTextureMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? textureId = null,}) {
  return _then(_UnregisterViewTextureMessage(
textureId: null == textureId ? _self.textureId : textureId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

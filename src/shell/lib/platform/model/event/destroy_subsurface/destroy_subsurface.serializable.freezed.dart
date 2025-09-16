// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'destroy_subsurface.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DestroySubsurfaceMessage {

 SurfaceId get surfaceId;
/// Create a copy of DestroySubsurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DestroySubsurfaceMessageCopyWith<DestroySubsurfaceMessage> get copyWith => _$DestroySubsurfaceMessageCopyWithImpl<DestroySubsurfaceMessage>(this as DestroySubsurfaceMessage, _$identity);

  /// Serializes this DestroySubsurfaceMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DestroySubsurfaceMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId);

@override
String toString() {
  return 'DestroySubsurfaceMessage(surfaceId: $surfaceId)';
}


}

/// @nodoc
abstract mixin class $DestroySubsurfaceMessageCopyWith<$Res>  {
  factory $DestroySubsurfaceMessageCopyWith(DestroySubsurfaceMessage value, $Res Function(DestroySubsurfaceMessage) _then) = _$DestroySubsurfaceMessageCopyWithImpl;
@useResult
$Res call({
 SurfaceId surfaceId
});




}
/// @nodoc
class _$DestroySubsurfaceMessageCopyWithImpl<$Res>
    implements $DestroySubsurfaceMessageCopyWith<$Res> {
  _$DestroySubsurfaceMessageCopyWithImpl(this._self, this._then);

  final DestroySubsurfaceMessage _self;
  final $Res Function(DestroySubsurfaceMessage) _then;

/// Create a copy of DestroySubsurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? surfaceId = null,}) {
  return _then(_self.copyWith(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,
  ));
}

}


/// Adds pattern-matching-related methods to [DestroySubsurfaceMessage].
extension DestroySubsurfaceMessagePatterns on DestroySubsurfaceMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DestroySubsurfaceMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DestroySubsurfaceMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DestroySubsurfaceMessage value)  $default,){
final _that = this;
switch (_that) {
case _DestroySubsurfaceMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DestroySubsurfaceMessage value)?  $default,){
final _that = this;
switch (_that) {
case _DestroySubsurfaceMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SurfaceId surfaceId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DestroySubsurfaceMessage() when $default != null:
return $default(_that.surfaceId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SurfaceId surfaceId)  $default,) {final _that = this;
switch (_that) {
case _DestroySubsurfaceMessage():
return $default(_that.surfaceId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SurfaceId surfaceId)?  $default,) {final _that = this;
switch (_that) {
case _DestroySubsurfaceMessage() when $default != null:
return $default(_that.surfaceId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DestroySubsurfaceMessage implements DestroySubsurfaceMessage {
   _DestroySubsurfaceMessage({required this.surfaceId});
  factory _DestroySubsurfaceMessage.fromJson(Map<String, dynamic> json) => _$DestroySubsurfaceMessageFromJson(json);

@override final  SurfaceId surfaceId;

/// Create a copy of DestroySubsurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DestroySubsurfaceMessageCopyWith<_DestroySubsurfaceMessage> get copyWith => __$DestroySubsurfaceMessageCopyWithImpl<_DestroySubsurfaceMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DestroySubsurfaceMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DestroySubsurfaceMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId);

@override
String toString() {
  return 'DestroySubsurfaceMessage(surfaceId: $surfaceId)';
}


}

/// @nodoc
abstract mixin class _$DestroySubsurfaceMessageCopyWith<$Res> implements $DestroySubsurfaceMessageCopyWith<$Res> {
  factory _$DestroySubsurfaceMessageCopyWith(_DestroySubsurfaceMessage value, $Res Function(_DestroySubsurfaceMessage) _then) = __$DestroySubsurfaceMessageCopyWithImpl;
@override @useResult
$Res call({
 SurfaceId surfaceId
});




}
/// @nodoc
class __$DestroySubsurfaceMessageCopyWithImpl<$Res>
    implements _$DestroySubsurfaceMessageCopyWith<$Res> {
  __$DestroySubsurfaceMessageCopyWithImpl(this._self, this._then);

  final _DestroySubsurfaceMessage _self;
  final $Res Function(_DestroySubsurfaceMessage) _then;

/// Create a copy of DestroySubsurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surfaceId = null,}) {
  return _then(_DestroySubsurfaceMessage(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,
  ));
}


}

// dart format on

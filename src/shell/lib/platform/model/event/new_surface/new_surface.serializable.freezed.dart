// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'new_surface.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NewSurfaceMessage {

 SurfaceId get surfaceId;
/// Create a copy of NewSurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSurfaceMessageCopyWith<NewSurfaceMessage> get copyWith => _$NewSurfaceMessageCopyWithImpl<NewSurfaceMessage>(this as NewSurfaceMessage, _$identity);

  /// Serializes this NewSurfaceMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSurfaceMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId);

@override
String toString() {
  return 'NewSurfaceMessage(surfaceId: $surfaceId)';
}


}

/// @nodoc
abstract mixin class $NewSurfaceMessageCopyWith<$Res>  {
  factory $NewSurfaceMessageCopyWith(NewSurfaceMessage value, $Res Function(NewSurfaceMessage) _then) = _$NewSurfaceMessageCopyWithImpl;
@useResult
$Res call({
 SurfaceId surfaceId
});




}
/// @nodoc
class _$NewSurfaceMessageCopyWithImpl<$Res>
    implements $NewSurfaceMessageCopyWith<$Res> {
  _$NewSurfaceMessageCopyWithImpl(this._self, this._then);

  final NewSurfaceMessage _self;
  final $Res Function(NewSurfaceMessage) _then;

/// Create a copy of NewSurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? surfaceId = null,}) {
  return _then(_self.copyWith(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,
  ));
}

}


/// Adds pattern-matching-related methods to [NewSurfaceMessage].
extension NewSurfaceMessagePatterns on NewSurfaceMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NewSurfaceMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NewSurfaceMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NewSurfaceMessage value)  $default,){
final _that = this;
switch (_that) {
case _NewSurfaceMessage():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NewSurfaceMessage value)?  $default,){
final _that = this;
switch (_that) {
case _NewSurfaceMessage() when $default != null:
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
case _NewSurfaceMessage() when $default != null:
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
case _NewSurfaceMessage():
return $default(_that.surfaceId);}
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
case _NewSurfaceMessage() when $default != null:
return $default(_that.surfaceId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NewSurfaceMessage implements NewSurfaceMessage {
   _NewSurfaceMessage({required this.surfaceId});
  factory _NewSurfaceMessage.fromJson(Map<String, dynamic> json) => _$NewSurfaceMessageFromJson(json);

@override final  SurfaceId surfaceId;

/// Create a copy of NewSurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewSurfaceMessageCopyWith<_NewSurfaceMessage> get copyWith => __$NewSurfaceMessageCopyWithImpl<_NewSurfaceMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NewSurfaceMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewSurfaceMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId);

@override
String toString() {
  return 'NewSurfaceMessage(surfaceId: $surfaceId)';
}


}

/// @nodoc
abstract mixin class _$NewSurfaceMessageCopyWith<$Res> implements $NewSurfaceMessageCopyWith<$Res> {
  factory _$NewSurfaceMessageCopyWith(_NewSurfaceMessage value, $Res Function(_NewSurfaceMessage) _then) = __$NewSurfaceMessageCopyWithImpl;
@override @useResult
$Res call({
 SurfaceId surfaceId
});




}
/// @nodoc
class __$NewSurfaceMessageCopyWithImpl<$Res>
    implements _$NewSurfaceMessageCopyWith<$Res> {
  __$NewSurfaceMessageCopyWithImpl(this._self, this._then);

  final _NewSurfaceMessage _self;
  final $Res Function(_NewSurfaceMessage) _then;

/// Create a copy of NewSurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surfaceId = null,}) {
  return _then(_NewSurfaceMessage(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,
  ));
}


}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'new_subsurface.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NewSubsurfaceMessage {

 SurfaceId get surfaceId; SurfaceId get parent;
/// Create a copy of NewSubsurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSubsurfaceMessageCopyWith<NewSubsurfaceMessage> get copyWith => _$NewSubsurfaceMessageCopyWithImpl<NewSubsurfaceMessage>(this as NewSubsurfaceMessage, _$identity);

  /// Serializes this NewSubsurfaceMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSubsurfaceMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.parent, parent) || other.parent == parent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId,parent);

@override
String toString() {
  return 'NewSubsurfaceMessage(surfaceId: $surfaceId, parent: $parent)';
}


}

/// @nodoc
abstract mixin class $NewSubsurfaceMessageCopyWith<$Res>  {
  factory $NewSubsurfaceMessageCopyWith(NewSubsurfaceMessage value, $Res Function(NewSubsurfaceMessage) _then) = _$NewSubsurfaceMessageCopyWithImpl;
@useResult
$Res call({
 SurfaceId surfaceId, SurfaceId parent
});




}
/// @nodoc
class _$NewSubsurfaceMessageCopyWithImpl<$Res>
    implements $NewSubsurfaceMessageCopyWith<$Res> {
  _$NewSubsurfaceMessageCopyWithImpl(this._self, this._then);

  final NewSubsurfaceMessage _self;
  final $Res Function(NewSubsurfaceMessage) _then;

/// Create a copy of NewSubsurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? surfaceId = null,Object? parent = null,}) {
  return _then(_self.copyWith(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,parent: null == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as SurfaceId,
  ));
}

}


/// Adds pattern-matching-related methods to [NewSubsurfaceMessage].
extension NewSubsurfaceMessagePatterns on NewSubsurfaceMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NewSubsurfaceMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NewSubsurfaceMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NewSubsurfaceMessage value)  $default,){
final _that = this;
switch (_that) {
case _NewSubsurfaceMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NewSubsurfaceMessage value)?  $default,){
final _that = this;
switch (_that) {
case _NewSubsurfaceMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SurfaceId surfaceId,  SurfaceId parent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NewSubsurfaceMessage() when $default != null:
return $default(_that.surfaceId,_that.parent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SurfaceId surfaceId,  SurfaceId parent)  $default,) {final _that = this;
switch (_that) {
case _NewSubsurfaceMessage():
return $default(_that.surfaceId,_that.parent);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SurfaceId surfaceId,  SurfaceId parent)?  $default,) {final _that = this;
switch (_that) {
case _NewSubsurfaceMessage() when $default != null:
return $default(_that.surfaceId,_that.parent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NewSubsurfaceMessage implements NewSubsurfaceMessage {
   _NewSubsurfaceMessage({required this.surfaceId, required this.parent});
  factory _NewSubsurfaceMessage.fromJson(Map<String, dynamic> json) => _$NewSubsurfaceMessageFromJson(json);

@override final  SurfaceId surfaceId;
@override final  SurfaceId parent;

/// Create a copy of NewSubsurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewSubsurfaceMessageCopyWith<_NewSubsurfaceMessage> get copyWith => __$NewSubsurfaceMessageCopyWithImpl<_NewSubsurfaceMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NewSubsurfaceMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewSubsurfaceMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.parent, parent) || other.parent == parent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId,parent);

@override
String toString() {
  return 'NewSubsurfaceMessage(surfaceId: $surfaceId, parent: $parent)';
}


}

/// @nodoc
abstract mixin class _$NewSubsurfaceMessageCopyWith<$Res> implements $NewSubsurfaceMessageCopyWith<$Res> {
  factory _$NewSubsurfaceMessageCopyWith(_NewSubsurfaceMessage value, $Res Function(_NewSubsurfaceMessage) _then) = __$NewSubsurfaceMessageCopyWithImpl;
@override @useResult
$Res call({
 SurfaceId surfaceId, SurfaceId parent
});




}
/// @nodoc
class __$NewSubsurfaceMessageCopyWithImpl<$Res>
    implements _$NewSubsurfaceMessageCopyWith<$Res> {
  __$NewSubsurfaceMessageCopyWithImpl(this._self, this._then);

  final _NewSubsurfaceMessage _self;
  final $Res Function(_NewSubsurfaceMessage) _then;

/// Create a copy of NewSubsurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surfaceId = null,Object? parent = null,}) {
  return _then(_NewSubsurfaceMessage(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,parent: null == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as SurfaceId,
  ));
}


}

// dart format on

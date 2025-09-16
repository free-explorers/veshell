// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pointer_focus.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PointerFocus {

 SurfaceId get surfaceId;@OffsetConverter() Offset get globalOffset;
/// Create a copy of PointerFocus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PointerFocusCopyWith<PointerFocus> get copyWith => _$PointerFocusCopyWithImpl<PointerFocus>(this as PointerFocus, _$identity);

  /// Serializes this PointerFocus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PointerFocus&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.globalOffset, globalOffset) || other.globalOffset == globalOffset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId,globalOffset);

@override
String toString() {
  return 'PointerFocus(surfaceId: $surfaceId, globalOffset: $globalOffset)';
}


}

/// @nodoc
abstract mixin class $PointerFocusCopyWith<$Res>  {
  factory $PointerFocusCopyWith(PointerFocus value, $Res Function(PointerFocus) _then) = _$PointerFocusCopyWithImpl;
@useResult
$Res call({
 SurfaceId surfaceId,@OffsetConverter() Offset globalOffset
});




}
/// @nodoc
class _$PointerFocusCopyWithImpl<$Res>
    implements $PointerFocusCopyWith<$Res> {
  _$PointerFocusCopyWithImpl(this._self, this._then);

  final PointerFocus _self;
  final $Res Function(PointerFocus) _then;

/// Create a copy of PointerFocus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? surfaceId = null,Object? globalOffset = null,}) {
  return _then(_self.copyWith(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,globalOffset: null == globalOffset ? _self.globalOffset : globalOffset // ignore: cast_nullable_to_non_nullable
as Offset,
  ));
}

}


/// Adds pattern-matching-related methods to [PointerFocus].
extension PointerFocusPatterns on PointerFocus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PointerFocus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PointerFocus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PointerFocus value)  $default,){
final _that = this;
switch (_that) {
case _PointerFocus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PointerFocus value)?  $default,){
final _that = this;
switch (_that) {
case _PointerFocus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SurfaceId surfaceId, @OffsetConverter()  Offset globalOffset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PointerFocus() when $default != null:
return $default(_that.surfaceId,_that.globalOffset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SurfaceId surfaceId, @OffsetConverter()  Offset globalOffset)  $default,) {final _that = this;
switch (_that) {
case _PointerFocus():
return $default(_that.surfaceId,_that.globalOffset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SurfaceId surfaceId, @OffsetConverter()  Offset globalOffset)?  $default,) {final _that = this;
switch (_that) {
case _PointerFocus() when $default != null:
return $default(_that.surfaceId,_that.globalOffset);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PointerFocus implements PointerFocus {
  const _PointerFocus({required this.surfaceId, @OffsetConverter() required this.globalOffset});
  factory _PointerFocus.fromJson(Map<String, dynamic> json) => _$PointerFocusFromJson(json);

@override final  SurfaceId surfaceId;
@override@OffsetConverter() final  Offset globalOffset;

/// Create a copy of PointerFocus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PointerFocusCopyWith<_PointerFocus> get copyWith => __$PointerFocusCopyWithImpl<_PointerFocus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PointerFocusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PointerFocus&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.globalOffset, globalOffset) || other.globalOffset == globalOffset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId,globalOffset);

@override
String toString() {
  return 'PointerFocus(surfaceId: $surfaceId, globalOffset: $globalOffset)';
}


}

/// @nodoc
abstract mixin class _$PointerFocusCopyWith<$Res> implements $PointerFocusCopyWith<$Res> {
  factory _$PointerFocusCopyWith(_PointerFocus value, $Res Function(_PointerFocus) _then) = __$PointerFocusCopyWithImpl;
@override @useResult
$Res call({
 SurfaceId surfaceId,@OffsetConverter() Offset globalOffset
});




}
/// @nodoc
class __$PointerFocusCopyWithImpl<$Res>
    implements _$PointerFocusCopyWith<$Res> {
  __$PointerFocusCopyWithImpl(this._self, this._then);

  final _PointerFocus _self;
  final $Res Function(_PointerFocus) _then;

/// Create a copy of PointerFocus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surfaceId = null,Object? globalOffset = null,}) {
  return _then(_PointerFocus(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,globalOffset: null == globalOffset ? _self.globalOffset : globalOffset // ignore: cast_nullable_to_non_nullable
as Offset,
  ));
}


}

// dart format on

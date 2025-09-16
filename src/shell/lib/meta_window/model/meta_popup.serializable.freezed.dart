// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meta_popup.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MetaPopup {

 MetaPopupId get id; MetaWindowId get parent; SurfaceId get surfaceId; double get scaleRatio;@OffsetConverter() Offset get position;@RectConverter() Rect? get geometry;
/// Create a copy of MetaPopup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaPopupCopyWith<MetaPopup> get copyWith => _$MetaPopupCopyWithImpl<MetaPopup>(this as MetaPopup, _$identity);

  /// Serializes this MetaPopup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaPopup&&(identical(other.id, id) || other.id == id)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.scaleRatio, scaleRatio) || other.scaleRatio == scaleRatio)&&(identical(other.position, position) || other.position == position)&&(identical(other.geometry, geometry) || other.geometry == geometry));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parent,surfaceId,scaleRatio,position,geometry);

@override
String toString() {
  return 'MetaPopup(id: $id, parent: $parent, surfaceId: $surfaceId, scaleRatio: $scaleRatio, position: $position, geometry: $geometry)';
}


}

/// @nodoc
abstract mixin class $MetaPopupCopyWith<$Res>  {
  factory $MetaPopupCopyWith(MetaPopup value, $Res Function(MetaPopup) _then) = _$MetaPopupCopyWithImpl;
@useResult
$Res call({
 MetaPopupId id, MetaWindowId parent, SurfaceId surfaceId, double scaleRatio,@OffsetConverter() Offset position,@RectConverter() Rect? geometry
});




}
/// @nodoc
class _$MetaPopupCopyWithImpl<$Res>
    implements $MetaPopupCopyWith<$Res> {
  _$MetaPopupCopyWithImpl(this._self, this._then);

  final MetaPopup _self;
  final $Res Function(MetaPopup) _then;

/// Create a copy of MetaPopup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? parent = null,Object? surfaceId = null,Object? scaleRatio = null,Object? position = null,Object? geometry = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as MetaPopupId,parent: null == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as MetaWindowId,surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,scaleRatio: null == scaleRatio ? _self.scaleRatio : scaleRatio // ignore: cast_nullable_to_non_nullable
as double,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Offset,geometry: freezed == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as Rect?,
  ));
}

}


/// Adds pattern-matching-related methods to [MetaPopup].
extension MetaPopupPatterns on MetaPopup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MetaPopup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MetaPopup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MetaPopup value)  $default,){
final _that = this;
switch (_that) {
case _MetaPopup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MetaPopup value)?  $default,){
final _that = this;
switch (_that) {
case _MetaPopup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MetaPopupId id,  MetaWindowId parent,  SurfaceId surfaceId,  double scaleRatio, @OffsetConverter()  Offset position, @RectConverter()  Rect? geometry)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MetaPopup() when $default != null:
return $default(_that.id,_that.parent,_that.surfaceId,_that.scaleRatio,_that.position,_that.geometry);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MetaPopupId id,  MetaWindowId parent,  SurfaceId surfaceId,  double scaleRatio, @OffsetConverter()  Offset position, @RectConverter()  Rect? geometry)  $default,) {final _that = this;
switch (_that) {
case _MetaPopup():
return $default(_that.id,_that.parent,_that.surfaceId,_that.scaleRatio,_that.position,_that.geometry);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MetaPopupId id,  MetaWindowId parent,  SurfaceId surfaceId,  double scaleRatio, @OffsetConverter()  Offset position, @RectConverter()  Rect? geometry)?  $default,) {final _that = this;
switch (_that) {
case _MetaPopup() when $default != null:
return $default(_that.id,_that.parent,_that.surfaceId,_that.scaleRatio,_that.position,_that.geometry);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MetaPopup implements MetaPopup {
  const _MetaPopup({required this.id, required this.parent, required this.surfaceId, required this.scaleRatio, @OffsetConverter() required this.position, @RectConverter() this.geometry});
  factory _MetaPopup.fromJson(Map<String, dynamic> json) => _$MetaPopupFromJson(json);

@override final  MetaPopupId id;
@override final  MetaWindowId parent;
@override final  SurfaceId surfaceId;
@override final  double scaleRatio;
@override@OffsetConverter() final  Offset position;
@override@RectConverter() final  Rect? geometry;

/// Create a copy of MetaPopup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MetaPopupCopyWith<_MetaPopup> get copyWith => __$MetaPopupCopyWithImpl<_MetaPopup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaPopupToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MetaPopup&&(identical(other.id, id) || other.id == id)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.scaleRatio, scaleRatio) || other.scaleRatio == scaleRatio)&&(identical(other.position, position) || other.position == position)&&(identical(other.geometry, geometry) || other.geometry == geometry));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parent,surfaceId,scaleRatio,position,geometry);

@override
String toString() {
  return 'MetaPopup(id: $id, parent: $parent, surfaceId: $surfaceId, scaleRatio: $scaleRatio, position: $position, geometry: $geometry)';
}


}

/// @nodoc
abstract mixin class _$MetaPopupCopyWith<$Res> implements $MetaPopupCopyWith<$Res> {
  factory _$MetaPopupCopyWith(_MetaPopup value, $Res Function(_MetaPopup) _then) = __$MetaPopupCopyWithImpl;
@override @useResult
$Res call({
 MetaPopupId id, MetaWindowId parent, SurfaceId surfaceId, double scaleRatio,@OffsetConverter() Offset position,@RectConverter() Rect? geometry
});




}
/// @nodoc
class __$MetaPopupCopyWithImpl<$Res>
    implements _$MetaPopupCopyWith<$Res> {
  __$MetaPopupCopyWithImpl(this._self, this._then);

  final _MetaPopup _self;
  final $Res Function(_MetaPopup) _then;

/// Create a copy of MetaPopup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parent = null,Object? surfaceId = null,Object? scaleRatio = null,Object? position = null,Object? geometry = freezed,}) {
  return _then(_MetaPopup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as MetaPopupId,parent: null == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as MetaWindowId,surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,scaleRatio: null == scaleRatio ? _self.scaleRatio : scaleRatio // ignore: cast_nullable_to_non_nullable
as double,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Offset,geometry: freezed == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as Rect?,
  ));
}


}

// dart format on

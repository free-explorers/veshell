// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subsurface.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Subsurface {

 bool get committed; bool get mapped; SurfaceId get parent; Offset get position;
/// Create a copy of Subsurface
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubsurfaceCopyWith<Subsurface> get copyWith => _$SubsurfaceCopyWithImpl<Subsurface>(this as Subsurface, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Subsurface&&(identical(other.committed, committed) || other.committed == committed)&&(identical(other.mapped, mapped) || other.mapped == mapped)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.position, position) || other.position == position));
}


@override
int get hashCode => Object.hash(runtimeType,committed,mapped,parent,position);

@override
String toString() {
  return 'Subsurface(committed: $committed, mapped: $mapped, parent: $parent, position: $position)';
}


}

/// @nodoc
abstract mixin class $SubsurfaceCopyWith<$Res>  {
  factory $SubsurfaceCopyWith(Subsurface value, $Res Function(Subsurface) _then) = _$SubsurfaceCopyWithImpl;
@useResult
$Res call({
 bool committed, bool mapped, SurfaceId parent, Offset position
});




}
/// @nodoc
class _$SubsurfaceCopyWithImpl<$Res>
    implements $SubsurfaceCopyWith<$Res> {
  _$SubsurfaceCopyWithImpl(this._self, this._then);

  final Subsurface _self;
  final $Res Function(Subsurface) _then;

/// Create a copy of Subsurface
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? committed = null,Object? mapped = null,Object? parent = null,Object? position = null,}) {
  return _then(_self.copyWith(
committed: null == committed ? _self.committed : committed // ignore: cast_nullable_to_non_nullable
as bool,mapped: null == mapped ? _self.mapped : mapped // ignore: cast_nullable_to_non_nullable
as bool,parent: null == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as SurfaceId,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Offset,
  ));
}

}


/// Adds pattern-matching-related methods to [Subsurface].
extension SubsurfacePatterns on Subsurface {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Subsurface value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Subsurface() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Subsurface value)  $default,){
final _that = this;
switch (_that) {
case _Subsurface():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Subsurface value)?  $default,){
final _that = this;
switch (_that) {
case _Subsurface() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool committed,  bool mapped,  SurfaceId parent,  Offset position)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Subsurface() when $default != null:
return $default(_that.committed,_that.mapped,_that.parent,_that.position);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool committed,  bool mapped,  SurfaceId parent,  Offset position)  $default,) {final _that = this;
switch (_that) {
case _Subsurface():
return $default(_that.committed,_that.mapped,_that.parent,_that.position);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool committed,  bool mapped,  SurfaceId parent,  Offset position)?  $default,) {final _that = this;
switch (_that) {
case _Subsurface() when $default != null:
return $default(_that.committed,_that.mapped,_that.parent,_that.position);case _:
  return null;

}
}

}

/// @nodoc


class _Subsurface implements Subsurface {
  const _Subsurface({required this.committed, required this.mapped, required this.parent, required this.position});
  

@override final  bool committed;
@override final  bool mapped;
@override final  SurfaceId parent;
@override final  Offset position;

/// Create a copy of Subsurface
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubsurfaceCopyWith<_Subsurface> get copyWith => __$SubsurfaceCopyWithImpl<_Subsurface>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Subsurface&&(identical(other.committed, committed) || other.committed == committed)&&(identical(other.mapped, mapped) || other.mapped == mapped)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.position, position) || other.position == position));
}


@override
int get hashCode => Object.hash(runtimeType,committed,mapped,parent,position);

@override
String toString() {
  return 'Subsurface(committed: $committed, mapped: $mapped, parent: $parent, position: $position)';
}


}

/// @nodoc
abstract mixin class _$SubsurfaceCopyWith<$Res> implements $SubsurfaceCopyWith<$Res> {
  factory _$SubsurfaceCopyWith(_Subsurface value, $Res Function(_Subsurface) _then) = __$SubsurfaceCopyWithImpl;
@override @useResult
$Res call({
 bool committed, bool mapped, SurfaceId parent, Offset position
});




}
/// @nodoc
class __$SubsurfaceCopyWithImpl<$Res>
    implements _$SubsurfaceCopyWith<$Res> {
  __$SubsurfaceCopyWithImpl(this._self, this._then);

  final _Subsurface _self;
  final $Res Function(_Subsurface) _then;

/// Create a copy of Subsurface
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? committed = null,Object? mapped = null,Object? parent = null,Object? position = null,}) {
  return _then(_Subsurface(
committed: null == committed ? _self.committed : committed // ignore: cast_nullable_to_non_nullable
as bool,mapped: null == mapped ? _self.mapped : mapped // ignore: cast_nullable_to_non_nullable
as bool,parent: null == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as SurfaceId,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Offset,
  ));
}


}

// dart format on

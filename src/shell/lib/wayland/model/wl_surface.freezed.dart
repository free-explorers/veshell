// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wl_surface.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SurfaceTexture {

 TextureId get id; Size get size;
/// Create a copy of SurfaceTexture
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SurfaceTextureCopyWith<SurfaceTexture> get copyWith => _$SurfaceTextureCopyWithImpl<SurfaceTexture>(this as SurfaceTexture, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SurfaceTexture&&(identical(other.id, id) || other.id == id)&&(identical(other.size, size) || other.size == size));
}


@override
int get hashCode => Object.hash(runtimeType,id,size);

@override
String toString() {
  return 'SurfaceTexture(id: $id, size: $size)';
}


}

/// @nodoc
abstract mixin class $SurfaceTextureCopyWith<$Res>  {
  factory $SurfaceTextureCopyWith(SurfaceTexture value, $Res Function(SurfaceTexture) _then) = _$SurfaceTextureCopyWithImpl;
@useResult
$Res call({
 TextureId id, Size size
});




}
/// @nodoc
class _$SurfaceTextureCopyWithImpl<$Res>
    implements $SurfaceTextureCopyWith<$Res> {
  _$SurfaceTextureCopyWithImpl(this._self, this._then);

  final SurfaceTexture _self;
  final $Res Function(SurfaceTexture) _then;

/// Create a copy of SurfaceTexture
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? size = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as TextureId,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as Size,
  ));
}

}


/// Adds pattern-matching-related methods to [SurfaceTexture].
extension SurfaceTexturePatterns on SurfaceTexture {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SurfaceTexture value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SurfaceTexture() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SurfaceTexture value)  $default,){
final _that = this;
switch (_that) {
case _SurfaceTexture():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SurfaceTexture value)?  $default,){
final _that = this;
switch (_that) {
case _SurfaceTexture() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TextureId id,  Size size)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SurfaceTexture() when $default != null:
return $default(_that.id,_that.size);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TextureId id,  Size size)  $default,) {final _that = this;
switch (_that) {
case _SurfaceTexture():
return $default(_that.id,_that.size);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TextureId id,  Size size)?  $default,) {final _that = this;
switch (_that) {
case _SurfaceTexture() when $default != null:
return $default(_that.id,_that.size);case _:
  return null;

}
}

}

/// @nodoc


class _SurfaceTexture implements SurfaceTexture {
  const _SurfaceTexture({required this.id, required this.size});
  

@override final  TextureId id;
@override final  Size size;

/// Create a copy of SurfaceTexture
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SurfaceTextureCopyWith<_SurfaceTexture> get copyWith => __$SurfaceTextureCopyWithImpl<_SurfaceTexture>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SurfaceTexture&&(identical(other.id, id) || other.id == id)&&(identical(other.size, size) || other.size == size));
}


@override
int get hashCode => Object.hash(runtimeType,id,size);

@override
String toString() {
  return 'SurfaceTexture(id: $id, size: $size)';
}


}

/// @nodoc
abstract mixin class _$SurfaceTextureCopyWith<$Res> implements $SurfaceTextureCopyWith<$Res> {
  factory _$SurfaceTextureCopyWith(_SurfaceTexture value, $Res Function(_SurfaceTexture) _then) = __$SurfaceTextureCopyWithImpl;
@override @useResult
$Res call({
 TextureId id, Size size
});




}
/// @nodoc
class __$SurfaceTextureCopyWithImpl<$Res>
    implements _$SurfaceTextureCopyWith<$Res> {
  __$SurfaceTextureCopyWithImpl(this._self, this._then);

  final _SurfaceTexture _self;
  final $Res Function(_SurfaceTexture) _then;

/// Create a copy of SurfaceTexture
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? size = null,}) {
  return _then(_SurfaceTexture(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as TextureId,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as Size,
  ));
}


}

/// @nodoc
mixin _$WlSurface {

 SurfaceId get surfaceId; SurfaceRole? get role; SurfaceTexture? get texture; int get scale; IList<int> get subsurfacesBelow; IList<int> get subsurfacesAbove; Rect get inputRegion;
/// Create a copy of WlSurface
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WlSurfaceCopyWith<WlSurface> get copyWith => _$WlSurfaceCopyWithImpl<WlSurface>(this as WlSurface, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WlSurface&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.role, role) || other.role == role)&&(identical(other.texture, texture) || other.texture == texture)&&(identical(other.scale, scale) || other.scale == scale)&&const DeepCollectionEquality().equals(other.subsurfacesBelow, subsurfacesBelow)&&const DeepCollectionEquality().equals(other.subsurfacesAbove, subsurfacesAbove)&&(identical(other.inputRegion, inputRegion) || other.inputRegion == inputRegion));
}


@override
int get hashCode => Object.hash(runtimeType,surfaceId,role,texture,scale,const DeepCollectionEquality().hash(subsurfacesBelow),const DeepCollectionEquality().hash(subsurfacesAbove),inputRegion);

@override
String toString() {
  return 'WlSurface(surfaceId: $surfaceId, role: $role, texture: $texture, scale: $scale, subsurfacesBelow: $subsurfacesBelow, subsurfacesAbove: $subsurfacesAbove, inputRegion: $inputRegion)';
}


}

/// @nodoc
abstract mixin class $WlSurfaceCopyWith<$Res>  {
  factory $WlSurfaceCopyWith(WlSurface value, $Res Function(WlSurface) _then) = _$WlSurfaceCopyWithImpl;
@useResult
$Res call({
 SurfaceId surfaceId, SurfaceRole? role, SurfaceTexture? texture, int scale, IList<int> subsurfacesBelow, IList<int> subsurfacesAbove, Rect inputRegion
});


$SurfaceTextureCopyWith<$Res>? get texture;

}
/// @nodoc
class _$WlSurfaceCopyWithImpl<$Res>
    implements $WlSurfaceCopyWith<$Res> {
  _$WlSurfaceCopyWithImpl(this._self, this._then);

  final WlSurface _self;
  final $Res Function(WlSurface) _then;

/// Create a copy of WlSurface
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? surfaceId = null,Object? role = freezed,Object? texture = freezed,Object? scale = null,Object? subsurfacesBelow = null,Object? subsurfacesAbove = null,Object? inputRegion = null,}) {
  return _then(_self.copyWith(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as SurfaceRole?,texture: freezed == texture ? _self.texture : texture // ignore: cast_nullable_to_non_nullable
as SurfaceTexture?,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as int,subsurfacesBelow: null == subsurfacesBelow ? _self.subsurfacesBelow : subsurfacesBelow // ignore: cast_nullable_to_non_nullable
as IList<int>,subsurfacesAbove: null == subsurfacesAbove ? _self.subsurfacesAbove : subsurfacesAbove // ignore: cast_nullable_to_non_nullable
as IList<int>,inputRegion: null == inputRegion ? _self.inputRegion : inputRegion // ignore: cast_nullable_to_non_nullable
as Rect,
  ));
}
/// Create a copy of WlSurface
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SurfaceTextureCopyWith<$Res>? get texture {
    if (_self.texture == null) {
    return null;
  }

  return $SurfaceTextureCopyWith<$Res>(_self.texture!, (value) {
    return _then(_self.copyWith(texture: value));
  });
}
}


/// Adds pattern-matching-related methods to [WlSurface].
extension WlSurfacePatterns on WlSurface {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WlSurface value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WlSurface() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WlSurface value)  $default,){
final _that = this;
switch (_that) {
case _WlSurface():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WlSurface value)?  $default,){
final _that = this;
switch (_that) {
case _WlSurface() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SurfaceId surfaceId,  SurfaceRole? role,  SurfaceTexture? texture,  int scale,  IList<int> subsurfacesBelow,  IList<int> subsurfacesAbove,  Rect inputRegion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WlSurface() when $default != null:
return $default(_that.surfaceId,_that.role,_that.texture,_that.scale,_that.subsurfacesBelow,_that.subsurfacesAbove,_that.inputRegion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SurfaceId surfaceId,  SurfaceRole? role,  SurfaceTexture? texture,  int scale,  IList<int> subsurfacesBelow,  IList<int> subsurfacesAbove,  Rect inputRegion)  $default,) {final _that = this;
switch (_that) {
case _WlSurface():
return $default(_that.surfaceId,_that.role,_that.texture,_that.scale,_that.subsurfacesBelow,_that.subsurfacesAbove,_that.inputRegion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SurfaceId surfaceId,  SurfaceRole? role,  SurfaceTexture? texture,  int scale,  IList<int> subsurfacesBelow,  IList<int> subsurfacesAbove,  Rect inputRegion)?  $default,) {final _that = this;
switch (_that) {
case _WlSurface() when $default != null:
return $default(_that.surfaceId,_that.role,_that.texture,_that.scale,_that.subsurfacesBelow,_that.subsurfacesAbove,_that.inputRegion);case _:
  return null;

}
}

}

/// @nodoc


class _WlSurface implements WlSurface {
  const _WlSurface({required this.surfaceId, required this.role, required this.texture, required this.scale, required this.subsurfacesBelow, required this.subsurfacesAbove, required this.inputRegion});
  

@override final  SurfaceId surfaceId;
@override final  SurfaceRole? role;
@override final  SurfaceTexture? texture;
@override final  int scale;
@override final  IList<int> subsurfacesBelow;
@override final  IList<int> subsurfacesAbove;
@override final  Rect inputRegion;

/// Create a copy of WlSurface
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WlSurfaceCopyWith<_WlSurface> get copyWith => __$WlSurfaceCopyWithImpl<_WlSurface>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WlSurface&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.role, role) || other.role == role)&&(identical(other.texture, texture) || other.texture == texture)&&(identical(other.scale, scale) || other.scale == scale)&&const DeepCollectionEquality().equals(other.subsurfacesBelow, subsurfacesBelow)&&const DeepCollectionEquality().equals(other.subsurfacesAbove, subsurfacesAbove)&&(identical(other.inputRegion, inputRegion) || other.inputRegion == inputRegion));
}


@override
int get hashCode => Object.hash(runtimeType,surfaceId,role,texture,scale,const DeepCollectionEquality().hash(subsurfacesBelow),const DeepCollectionEquality().hash(subsurfacesAbove),inputRegion);

@override
String toString() {
  return 'WlSurface(surfaceId: $surfaceId, role: $role, texture: $texture, scale: $scale, subsurfacesBelow: $subsurfacesBelow, subsurfacesAbove: $subsurfacesAbove, inputRegion: $inputRegion)';
}


}

/// @nodoc
abstract mixin class _$WlSurfaceCopyWith<$Res> implements $WlSurfaceCopyWith<$Res> {
  factory _$WlSurfaceCopyWith(_WlSurface value, $Res Function(_WlSurface) _then) = __$WlSurfaceCopyWithImpl;
@override @useResult
$Res call({
 SurfaceId surfaceId, SurfaceRole? role, SurfaceTexture? texture, int scale, IList<int> subsurfacesBelow, IList<int> subsurfacesAbove, Rect inputRegion
});


@override $SurfaceTextureCopyWith<$Res>? get texture;

}
/// @nodoc
class __$WlSurfaceCopyWithImpl<$Res>
    implements _$WlSurfaceCopyWith<$Res> {
  __$WlSurfaceCopyWithImpl(this._self, this._then);

  final _WlSurface _self;
  final $Res Function(_WlSurface) _then;

/// Create a copy of WlSurface
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surfaceId = null,Object? role = freezed,Object? texture = freezed,Object? scale = null,Object? subsurfacesBelow = null,Object? subsurfacesAbove = null,Object? inputRegion = null,}) {
  return _then(_WlSurface(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as SurfaceRole?,texture: freezed == texture ? _self.texture : texture // ignore: cast_nullable_to_non_nullable
as SurfaceTexture?,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as int,subsurfacesBelow: null == subsurfacesBelow ? _self.subsurfacesBelow : subsurfacesBelow // ignore: cast_nullable_to_non_nullable
as IList<int>,subsurfacesAbove: null == subsurfacesAbove ? _self.subsurfacesAbove : subsurfacesAbove // ignore: cast_nullable_to_non_nullable
as IList<int>,inputRegion: null == inputRegion ? _self.inputRegion : inputRegion // ignore: cast_nullable_to_non_nullable
as Rect,
  ));
}

/// Create a copy of WlSurface
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SurfaceTextureCopyWith<$Res>? get texture {
    if (_self.texture == null) {
    return null;
  }

  return $SurfaceTextureCopyWith<$Res>(_self.texture!, (value) {
    return _then(_self.copyWith(texture: value));
  });
}
}

// dart format on

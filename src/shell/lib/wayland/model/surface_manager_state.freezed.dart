// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'surface_manager_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SurfaceManagerState {

 ISet<SurfaceId> get wlSurfaces; ISet<SurfaceId> get subSurfaces;
/// Create a copy of SurfaceManagerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SurfaceManagerStateCopyWith<SurfaceManagerState> get copyWith => _$SurfaceManagerStateCopyWithImpl<SurfaceManagerState>(this as SurfaceManagerState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SurfaceManagerState&&const DeepCollectionEquality().equals(other.wlSurfaces, wlSurfaces)&&const DeepCollectionEquality().equals(other.subSurfaces, subSurfaces));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(wlSurfaces),const DeepCollectionEquality().hash(subSurfaces));

@override
String toString() {
  return 'SurfaceManagerState(wlSurfaces: $wlSurfaces, subSurfaces: $subSurfaces)';
}


}

/// @nodoc
abstract mixin class $SurfaceManagerStateCopyWith<$Res>  {
  factory $SurfaceManagerStateCopyWith(SurfaceManagerState value, $Res Function(SurfaceManagerState) _then) = _$SurfaceManagerStateCopyWithImpl;
@useResult
$Res call({
 ISet<SurfaceId> wlSurfaces, ISet<SurfaceId> subSurfaces
});




}
/// @nodoc
class _$SurfaceManagerStateCopyWithImpl<$Res>
    implements $SurfaceManagerStateCopyWith<$Res> {
  _$SurfaceManagerStateCopyWithImpl(this._self, this._then);

  final SurfaceManagerState _self;
  final $Res Function(SurfaceManagerState) _then;

/// Create a copy of SurfaceManagerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? wlSurfaces = null,Object? subSurfaces = null,}) {
  return _then(_self.copyWith(
wlSurfaces: null == wlSurfaces ? _self.wlSurfaces : wlSurfaces // ignore: cast_nullable_to_non_nullable
as ISet<SurfaceId>,subSurfaces: null == subSurfaces ? _self.subSurfaces : subSurfaces // ignore: cast_nullable_to_non_nullable
as ISet<SurfaceId>,
  ));
}

}


/// Adds pattern-matching-related methods to [SurfaceManagerState].
extension SurfaceManagerStatePatterns on SurfaceManagerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SurfaceManagerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SurfaceManagerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SurfaceManagerState value)  $default,){
final _that = this;
switch (_that) {
case _SurfaceManagerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SurfaceManagerState value)?  $default,){
final _that = this;
switch (_that) {
case _SurfaceManagerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ISet<SurfaceId> wlSurfaces,  ISet<SurfaceId> subSurfaces)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SurfaceManagerState() when $default != null:
return $default(_that.wlSurfaces,_that.subSurfaces);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ISet<SurfaceId> wlSurfaces,  ISet<SurfaceId> subSurfaces)  $default,) {final _that = this;
switch (_that) {
case _SurfaceManagerState():
return $default(_that.wlSurfaces,_that.subSurfaces);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ISet<SurfaceId> wlSurfaces,  ISet<SurfaceId> subSurfaces)?  $default,) {final _that = this;
switch (_that) {
case _SurfaceManagerState() when $default != null:
return $default(_that.wlSurfaces,_that.subSurfaces);case _:
  return null;

}
}

}

/// @nodoc


class _SurfaceManagerState implements SurfaceManagerState {
  const _SurfaceManagerState({required this.wlSurfaces, required this.subSurfaces});
  

@override final  ISet<SurfaceId> wlSurfaces;
@override final  ISet<SurfaceId> subSurfaces;

/// Create a copy of SurfaceManagerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SurfaceManagerStateCopyWith<_SurfaceManagerState> get copyWith => __$SurfaceManagerStateCopyWithImpl<_SurfaceManagerState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SurfaceManagerState&&const DeepCollectionEquality().equals(other.wlSurfaces, wlSurfaces)&&const DeepCollectionEquality().equals(other.subSurfaces, subSurfaces));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(wlSurfaces),const DeepCollectionEquality().hash(subSurfaces));

@override
String toString() {
  return 'SurfaceManagerState(wlSurfaces: $wlSurfaces, subSurfaces: $subSurfaces)';
}


}

/// @nodoc
abstract mixin class _$SurfaceManagerStateCopyWith<$Res> implements $SurfaceManagerStateCopyWith<$Res> {
  factory _$SurfaceManagerStateCopyWith(_SurfaceManagerState value, $Res Function(_SurfaceManagerState) _then) = __$SurfaceManagerStateCopyWithImpl;
@override @useResult
$Res call({
 ISet<SurfaceId> wlSurfaces, ISet<SurfaceId> subSurfaces
});




}
/// @nodoc
class __$SurfaceManagerStateCopyWithImpl<$Res>
    implements _$SurfaceManagerStateCopyWith<$Res> {
  __$SurfaceManagerStateCopyWithImpl(this._self, this._then);

  final _SurfaceManagerState _self;
  final $Res Function(_SurfaceManagerState) _then;

/// Create a copy of SurfaceManagerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? wlSurfaces = null,Object? subSurfaces = null,}) {
  return _then(_SurfaceManagerState(
wlSurfaces: null == wlSurfaces ? _self.wlSurfaces : wlSurfaces // ignore: cast_nullable_to_non_nullable
as ISet<SurfaceId>,subSurfaces: null == subSurfaces ? _self.subSurfaces : subSurfaces // ignore: cast_nullable_to_non_nullable
as ISet<SurfaceId>,
  ));
}


}

// dart format on

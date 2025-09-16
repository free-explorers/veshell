// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ephemeral_window.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EphemeralWindow {

 EphemeralWindowId get windowId; WindowProperties get properties; ScreenId get screenId; MetaWindowId? get metaWindowId;
/// Create a copy of EphemeralWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EphemeralWindowCopyWith<EphemeralWindow> get copyWith => _$EphemeralWindowCopyWithImpl<EphemeralWindow>(this as EphemeralWindow, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EphemeralWindow&&const DeepCollectionEquality().equals(other.windowId, windowId)&&(identical(other.properties, properties) || other.properties == properties)&&(identical(other.screenId, screenId) || other.screenId == screenId)&&(identical(other.metaWindowId, metaWindowId) || other.metaWindowId == metaWindowId));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(windowId),properties,screenId,metaWindowId);

@override
String toString() {
  return 'EphemeralWindow(windowId: $windowId, properties: $properties, screenId: $screenId, metaWindowId: $metaWindowId)';
}


}

/// @nodoc
abstract mixin class $EphemeralWindowCopyWith<$Res>  {
  factory $EphemeralWindowCopyWith(EphemeralWindow value, $Res Function(EphemeralWindow) _then) = _$EphemeralWindowCopyWithImpl;
@useResult
$Res call({
 EphemeralWindowId windowId, WindowProperties properties, ScreenId screenId, MetaWindowId? metaWindowId
});


$WindowPropertiesCopyWith<$Res> get properties;

}
/// @nodoc
class _$EphemeralWindowCopyWithImpl<$Res>
    implements $EphemeralWindowCopyWith<$Res> {
  _$EphemeralWindowCopyWithImpl(this._self, this._then);

  final EphemeralWindow _self;
  final $Res Function(EphemeralWindow) _then;

/// Create a copy of EphemeralWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? windowId = freezed,Object? properties = null,Object? screenId = null,Object? metaWindowId = freezed,}) {
  return _then(_self.copyWith(
windowId: freezed == windowId ? _self.windowId : windowId // ignore: cast_nullable_to_non_nullable
as EphemeralWindowId,properties: null == properties ? _self.properties : properties // ignore: cast_nullable_to_non_nullable
as WindowProperties,screenId: null == screenId ? _self.screenId : screenId // ignore: cast_nullable_to_non_nullable
as ScreenId,metaWindowId: freezed == metaWindowId ? _self.metaWindowId : metaWindowId // ignore: cast_nullable_to_non_nullable
as MetaWindowId?,
  ));
}
/// Create a copy of EphemeralWindow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowPropertiesCopyWith<$Res> get properties {
  
  return $WindowPropertiesCopyWith<$Res>(_self.properties, (value) {
    return _then(_self.copyWith(properties: value));
  });
}
}


/// Adds pattern-matching-related methods to [EphemeralWindow].
extension EphemeralWindowPatterns on EphemeralWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EphemeralWindow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EphemeralWindow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EphemeralWindow value)  $default,){
final _that = this;
switch (_that) {
case _EphemeralWindow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EphemeralWindow value)?  $default,){
final _that = this;
switch (_that) {
case _EphemeralWindow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( EphemeralWindowId windowId,  WindowProperties properties,  ScreenId screenId,  MetaWindowId? metaWindowId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EphemeralWindow() when $default != null:
return $default(_that.windowId,_that.properties,_that.screenId,_that.metaWindowId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( EphemeralWindowId windowId,  WindowProperties properties,  ScreenId screenId,  MetaWindowId? metaWindowId)  $default,) {final _that = this;
switch (_that) {
case _EphemeralWindow():
return $default(_that.windowId,_that.properties,_that.screenId,_that.metaWindowId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( EphemeralWindowId windowId,  WindowProperties properties,  ScreenId screenId,  MetaWindowId? metaWindowId)?  $default,) {final _that = this;
switch (_that) {
case _EphemeralWindow() when $default != null:
return $default(_that.windowId,_that.properties,_that.screenId,_that.metaWindowId);case _:
  return null;

}
}

}

/// @nodoc


class _EphemeralWindow implements EphemeralWindow {
  const _EphemeralWindow({required this.windowId, required this.properties, required this.screenId, this.metaWindowId});
  

@override final  EphemeralWindowId windowId;
@override final  WindowProperties properties;
@override final  ScreenId screenId;
@override final  MetaWindowId? metaWindowId;

/// Create a copy of EphemeralWindow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EphemeralWindowCopyWith<_EphemeralWindow> get copyWith => __$EphemeralWindowCopyWithImpl<_EphemeralWindow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EphemeralWindow&&const DeepCollectionEquality().equals(other.windowId, windowId)&&(identical(other.properties, properties) || other.properties == properties)&&(identical(other.screenId, screenId) || other.screenId == screenId)&&(identical(other.metaWindowId, metaWindowId) || other.metaWindowId == metaWindowId));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(windowId),properties,screenId,metaWindowId);

@override
String toString() {
  return 'EphemeralWindow(windowId: $windowId, properties: $properties, screenId: $screenId, metaWindowId: $metaWindowId)';
}


}

/// @nodoc
abstract mixin class _$EphemeralWindowCopyWith<$Res> implements $EphemeralWindowCopyWith<$Res> {
  factory _$EphemeralWindowCopyWith(_EphemeralWindow value, $Res Function(_EphemeralWindow) _then) = __$EphemeralWindowCopyWithImpl;
@override @useResult
$Res call({
 EphemeralWindowId windowId, WindowProperties properties, ScreenId screenId, MetaWindowId? metaWindowId
});


@override $WindowPropertiesCopyWith<$Res> get properties;

}
/// @nodoc
class __$EphemeralWindowCopyWithImpl<$Res>
    implements _$EphemeralWindowCopyWith<$Res> {
  __$EphemeralWindowCopyWithImpl(this._self, this._then);

  final _EphemeralWindow _self;
  final $Res Function(_EphemeralWindow) _then;

/// Create a copy of EphemeralWindow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? windowId = freezed,Object? properties = null,Object? screenId = null,Object? metaWindowId = freezed,}) {
  return _then(_EphemeralWindow(
windowId: freezed == windowId ? _self.windowId : windowId // ignore: cast_nullable_to_non_nullable
as EphemeralWindowId,properties: null == properties ? _self.properties : properties // ignore: cast_nullable_to_non_nullable
as WindowProperties,screenId: null == screenId ? _self.screenId : screenId // ignore: cast_nullable_to_non_nullable
as ScreenId,metaWindowId: freezed == metaWindowId ? _self.metaWindowId : metaWindowId // ignore: cast_nullable_to_non_nullable
as MetaWindowId?,
  ));
}

/// Create a copy of EphemeralWindow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowPropertiesCopyWith<$Res> get properties {
  
  return $WindowPropertiesCopyWith<$Res>(_self.properties, (value) {
    return _then(_self.copyWith(properties: value));
  });
}
}

// dart format on

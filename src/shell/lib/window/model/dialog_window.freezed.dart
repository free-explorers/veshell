// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dialog_window.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DialogWindow {

 DialogWindowId get windowId; WindowProperties get properties; MetaWindowId get metaWindowId; WindowId get parentWindowId;
/// Create a copy of DialogWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DialogWindowCopyWith<DialogWindow> get copyWith => _$DialogWindowCopyWithImpl<DialogWindow>(this as DialogWindow, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DialogWindow&&const DeepCollectionEquality().equals(other.windowId, windowId)&&(identical(other.properties, properties) || other.properties == properties)&&(identical(other.metaWindowId, metaWindowId) || other.metaWindowId == metaWindowId)&&(identical(other.parentWindowId, parentWindowId) || other.parentWindowId == parentWindowId));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(windowId),properties,metaWindowId,parentWindowId);

@override
String toString() {
  return 'DialogWindow(windowId: $windowId, properties: $properties, metaWindowId: $metaWindowId, parentWindowId: $parentWindowId)';
}


}

/// @nodoc
abstract mixin class $DialogWindowCopyWith<$Res>  {
  factory $DialogWindowCopyWith(DialogWindow value, $Res Function(DialogWindow) _then) = _$DialogWindowCopyWithImpl;
@useResult
$Res call({
 DialogWindowId windowId, WindowProperties properties, MetaWindowId metaWindowId, WindowId parentWindowId
});


$WindowPropertiesCopyWith<$Res> get properties;$WindowIdCopyWith<$Res> get parentWindowId;

}
/// @nodoc
class _$DialogWindowCopyWithImpl<$Res>
    implements $DialogWindowCopyWith<$Res> {
  _$DialogWindowCopyWithImpl(this._self, this._then);

  final DialogWindow _self;
  final $Res Function(DialogWindow) _then;

/// Create a copy of DialogWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? windowId = freezed,Object? properties = null,Object? metaWindowId = null,Object? parentWindowId = null,}) {
  return _then(_self.copyWith(
windowId: freezed == windowId ? _self.windowId : windowId // ignore: cast_nullable_to_non_nullable
as DialogWindowId,properties: null == properties ? _self.properties : properties // ignore: cast_nullable_to_non_nullable
as WindowProperties,metaWindowId: null == metaWindowId ? _self.metaWindowId : metaWindowId // ignore: cast_nullable_to_non_nullable
as MetaWindowId,parentWindowId: null == parentWindowId ? _self.parentWindowId : parentWindowId // ignore: cast_nullable_to_non_nullable
as WindowId,
  ));
}
/// Create a copy of DialogWindow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowPropertiesCopyWith<$Res> get properties {
  
  return $WindowPropertiesCopyWith<$Res>(_self.properties, (value) {
    return _then(_self.copyWith(properties: value));
  });
}/// Create a copy of DialogWindow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowIdCopyWith<$Res> get parentWindowId {
  
  return $WindowIdCopyWith<$Res>(_self.parentWindowId, (value) {
    return _then(_self.copyWith(parentWindowId: value));
  });
}
}


/// Adds pattern-matching-related methods to [DialogWindow].
extension DialogWindowPatterns on DialogWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DialogWindow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DialogWindow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DialogWindow value)  $default,){
final _that = this;
switch (_that) {
case _DialogWindow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DialogWindow value)?  $default,){
final _that = this;
switch (_that) {
case _DialogWindow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DialogWindowId windowId,  WindowProperties properties,  MetaWindowId metaWindowId,  WindowId parentWindowId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DialogWindow() when $default != null:
return $default(_that.windowId,_that.properties,_that.metaWindowId,_that.parentWindowId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DialogWindowId windowId,  WindowProperties properties,  MetaWindowId metaWindowId,  WindowId parentWindowId)  $default,) {final _that = this;
switch (_that) {
case _DialogWindow():
return $default(_that.windowId,_that.properties,_that.metaWindowId,_that.parentWindowId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DialogWindowId windowId,  WindowProperties properties,  MetaWindowId metaWindowId,  WindowId parentWindowId)?  $default,) {final _that = this;
switch (_that) {
case _DialogWindow() when $default != null:
return $default(_that.windowId,_that.properties,_that.metaWindowId,_that.parentWindowId);case _:
  return null;

}
}

}

/// @nodoc


class _DialogWindow implements DialogWindow {
  const _DialogWindow({required this.windowId, required this.properties, required this.metaWindowId, required this.parentWindowId});
  

@override final  DialogWindowId windowId;
@override final  WindowProperties properties;
@override final  MetaWindowId metaWindowId;
@override final  WindowId parentWindowId;

/// Create a copy of DialogWindow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DialogWindowCopyWith<_DialogWindow> get copyWith => __$DialogWindowCopyWithImpl<_DialogWindow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DialogWindow&&const DeepCollectionEquality().equals(other.windowId, windowId)&&(identical(other.properties, properties) || other.properties == properties)&&(identical(other.metaWindowId, metaWindowId) || other.metaWindowId == metaWindowId)&&(identical(other.parentWindowId, parentWindowId) || other.parentWindowId == parentWindowId));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(windowId),properties,metaWindowId,parentWindowId);

@override
String toString() {
  return 'DialogWindow(windowId: $windowId, properties: $properties, metaWindowId: $metaWindowId, parentWindowId: $parentWindowId)';
}


}

/// @nodoc
abstract mixin class _$DialogWindowCopyWith<$Res> implements $DialogWindowCopyWith<$Res> {
  factory _$DialogWindowCopyWith(_DialogWindow value, $Res Function(_DialogWindow) _then) = __$DialogWindowCopyWithImpl;
@override @useResult
$Res call({
 DialogWindowId windowId, WindowProperties properties, MetaWindowId metaWindowId, WindowId parentWindowId
});


@override $WindowPropertiesCopyWith<$Res> get properties;@override $WindowIdCopyWith<$Res> get parentWindowId;

}
/// @nodoc
class __$DialogWindowCopyWithImpl<$Res>
    implements _$DialogWindowCopyWith<$Res> {
  __$DialogWindowCopyWithImpl(this._self, this._then);

  final _DialogWindow _self;
  final $Res Function(_DialogWindow) _then;

/// Create a copy of DialogWindow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? windowId = freezed,Object? properties = null,Object? metaWindowId = null,Object? parentWindowId = null,}) {
  return _then(_DialogWindow(
windowId: freezed == windowId ? _self.windowId : windowId // ignore: cast_nullable_to_non_nullable
as DialogWindowId,properties: null == properties ? _self.properties : properties // ignore: cast_nullable_to_non_nullable
as WindowProperties,metaWindowId: null == metaWindowId ? _self.metaWindowId : metaWindowId // ignore: cast_nullable_to_non_nullable
as MetaWindowId,parentWindowId: null == parentWindowId ? _self.parentWindowId : parentWindowId // ignore: cast_nullable_to_non_nullable
as WindowId,
  ));
}

/// Create a copy of DialogWindow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowPropertiesCopyWith<$Res> get properties {
  
  return $WindowPropertiesCopyWith<$Res>(_self.properties, (value) {
    return _then(_self.copyWith(properties: value));
  });
}/// Create a copy of DialogWindow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowIdCopyWith<$Res> get parentWindowId {
  
  return $WindowIdCopyWith<$Res>(_self.parentWindowId, (value) {
    return _then(_self.copyWith(parentWindowId: value));
  });
}
}

// dart format on

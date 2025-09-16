// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'persistent_window.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PersistentWindow {

 PersistentWindowId get windowId; WindowProperties get properties; MetaWindowId? get metaWindowId; bool get isWaitingForSurface; DisplayMode get displayMode; String? get customExec; int? get pid;
/// Create a copy of PersistentWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PersistentWindowCopyWith<PersistentWindow> get copyWith => _$PersistentWindowCopyWithImpl<PersistentWindow>(this as PersistentWindow, _$identity);

  /// Serializes this PersistentWindow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PersistentWindow&&const DeepCollectionEquality().equals(other.windowId, windowId)&&(identical(other.properties, properties) || other.properties == properties)&&(identical(other.metaWindowId, metaWindowId) || other.metaWindowId == metaWindowId)&&(identical(other.isWaitingForSurface, isWaitingForSurface) || other.isWaitingForSurface == isWaitingForSurface)&&(identical(other.displayMode, displayMode) || other.displayMode == displayMode)&&(identical(other.customExec, customExec) || other.customExec == customExec)&&(identical(other.pid, pid) || other.pid == pid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(windowId),properties,metaWindowId,isWaitingForSurface,displayMode,customExec,pid);

@override
String toString() {
  return 'PersistentWindow(windowId: $windowId, properties: $properties, metaWindowId: $metaWindowId, isWaitingForSurface: $isWaitingForSurface, displayMode: $displayMode, customExec: $customExec, pid: $pid)';
}


}

/// @nodoc
abstract mixin class $PersistentWindowCopyWith<$Res>  {
  factory $PersistentWindowCopyWith(PersistentWindow value, $Res Function(PersistentWindow) _then) = _$PersistentWindowCopyWithImpl;
@useResult
$Res call({
 PersistentWindowId windowId, WindowProperties properties, MetaWindowId? metaWindowId, bool isWaitingForSurface, DisplayMode displayMode, String? customExec, int? pid
});


$WindowPropertiesCopyWith<$Res> get properties;

}
/// @nodoc
class _$PersistentWindowCopyWithImpl<$Res>
    implements $PersistentWindowCopyWith<$Res> {
  _$PersistentWindowCopyWithImpl(this._self, this._then);

  final PersistentWindow _self;
  final $Res Function(PersistentWindow) _then;

/// Create a copy of PersistentWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? windowId = freezed,Object? properties = null,Object? metaWindowId = freezed,Object? isWaitingForSurface = null,Object? displayMode = null,Object? customExec = freezed,Object? pid = freezed,}) {
  return _then(_self.copyWith(
windowId: freezed == windowId ? _self.windowId : windowId // ignore: cast_nullable_to_non_nullable
as PersistentWindowId,properties: null == properties ? _self.properties : properties // ignore: cast_nullable_to_non_nullable
as WindowProperties,metaWindowId: freezed == metaWindowId ? _self.metaWindowId : metaWindowId // ignore: cast_nullable_to_non_nullable
as MetaWindowId?,isWaitingForSurface: null == isWaitingForSurface ? _self.isWaitingForSurface : isWaitingForSurface // ignore: cast_nullable_to_non_nullable
as bool,displayMode: null == displayMode ? _self.displayMode : displayMode // ignore: cast_nullable_to_non_nullable
as DisplayMode,customExec: freezed == customExec ? _self.customExec : customExec // ignore: cast_nullable_to_non_nullable
as String?,pid: freezed == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of PersistentWindow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowPropertiesCopyWith<$Res> get properties {
  
  return $WindowPropertiesCopyWith<$Res>(_self.properties, (value) {
    return _then(_self.copyWith(properties: value));
  });
}
}


/// Adds pattern-matching-related methods to [PersistentWindow].
extension PersistentWindowPatterns on PersistentWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PersistentWindow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PersistentWindow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PersistentWindow value)  $default,){
final _that = this;
switch (_that) {
case _PersistentWindow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PersistentWindow value)?  $default,){
final _that = this;
switch (_that) {
case _PersistentWindow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PersistentWindowId windowId,  WindowProperties properties,  MetaWindowId? metaWindowId,  bool isWaitingForSurface,  DisplayMode displayMode,  String? customExec,  int? pid)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PersistentWindow() when $default != null:
return $default(_that.windowId,_that.properties,_that.metaWindowId,_that.isWaitingForSurface,_that.displayMode,_that.customExec,_that.pid);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PersistentWindowId windowId,  WindowProperties properties,  MetaWindowId? metaWindowId,  bool isWaitingForSurface,  DisplayMode displayMode,  String? customExec,  int? pid)  $default,) {final _that = this;
switch (_that) {
case _PersistentWindow():
return $default(_that.windowId,_that.properties,_that.metaWindowId,_that.isWaitingForSurface,_that.displayMode,_that.customExec,_that.pid);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PersistentWindowId windowId,  WindowProperties properties,  MetaWindowId? metaWindowId,  bool isWaitingForSurface,  DisplayMode displayMode,  String? customExec,  int? pid)?  $default,) {final _that = this;
switch (_that) {
case _PersistentWindow() when $default != null:
return $default(_that.windowId,_that.properties,_that.metaWindowId,_that.isWaitingForSurface,_that.displayMode,_that.customExec,_that.pid);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PersistentWindow extends PersistentWindow {
  const _PersistentWindow({required this.windowId, required this.properties, this.metaWindowId, this.isWaitingForSurface = false, this.displayMode = DisplayMode.maximized, this.customExec, this.pid}): super._();
  factory _PersistentWindow.fromJson(Map<String, dynamic> json) => _$PersistentWindowFromJson(json);

@override final  PersistentWindowId windowId;
@override final  WindowProperties properties;
@override final  MetaWindowId? metaWindowId;
@override@JsonKey() final  bool isWaitingForSurface;
@override@JsonKey() final  DisplayMode displayMode;
@override final  String? customExec;
@override final  int? pid;

/// Create a copy of PersistentWindow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PersistentWindowCopyWith<_PersistentWindow> get copyWith => __$PersistentWindowCopyWithImpl<_PersistentWindow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PersistentWindowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PersistentWindow&&const DeepCollectionEquality().equals(other.windowId, windowId)&&(identical(other.properties, properties) || other.properties == properties)&&(identical(other.metaWindowId, metaWindowId) || other.metaWindowId == metaWindowId)&&(identical(other.isWaitingForSurface, isWaitingForSurface) || other.isWaitingForSurface == isWaitingForSurface)&&(identical(other.displayMode, displayMode) || other.displayMode == displayMode)&&(identical(other.customExec, customExec) || other.customExec == customExec)&&(identical(other.pid, pid) || other.pid == pid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(windowId),properties,metaWindowId,isWaitingForSurface,displayMode,customExec,pid);

@override
String toString() {
  return 'PersistentWindow(windowId: $windowId, properties: $properties, metaWindowId: $metaWindowId, isWaitingForSurface: $isWaitingForSurface, displayMode: $displayMode, customExec: $customExec, pid: $pid)';
}


}

/// @nodoc
abstract mixin class _$PersistentWindowCopyWith<$Res> implements $PersistentWindowCopyWith<$Res> {
  factory _$PersistentWindowCopyWith(_PersistentWindow value, $Res Function(_PersistentWindow) _then) = __$PersistentWindowCopyWithImpl;
@override @useResult
$Res call({
 PersistentWindowId windowId, WindowProperties properties, MetaWindowId? metaWindowId, bool isWaitingForSurface, DisplayMode displayMode, String? customExec, int? pid
});


@override $WindowPropertiesCopyWith<$Res> get properties;

}
/// @nodoc
class __$PersistentWindowCopyWithImpl<$Res>
    implements _$PersistentWindowCopyWith<$Res> {
  __$PersistentWindowCopyWithImpl(this._self, this._then);

  final _PersistentWindow _self;
  final $Res Function(_PersistentWindow) _then;

/// Create a copy of PersistentWindow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? windowId = freezed,Object? properties = null,Object? metaWindowId = freezed,Object? isWaitingForSurface = null,Object? displayMode = null,Object? customExec = freezed,Object? pid = freezed,}) {
  return _then(_PersistentWindow(
windowId: freezed == windowId ? _self.windowId : windowId // ignore: cast_nullable_to_non_nullable
as PersistentWindowId,properties: null == properties ? _self.properties : properties // ignore: cast_nullable_to_non_nullable
as WindowProperties,metaWindowId: freezed == metaWindowId ? _self.metaWindowId : metaWindowId // ignore: cast_nullable_to_non_nullable
as MetaWindowId?,isWaitingForSurface: null == isWaitingForSurface ? _self.isWaitingForSurface : isWaitingForSurface // ignore: cast_nullable_to_non_nullable
as bool,displayMode: null == displayMode ? _self.displayMode : displayMode // ignore: cast_nullable_to_non_nullable
as DisplayMode,customExec: freezed == customExec ? _self.customExec : customExec // ignore: cast_nullable_to_non_nullable
as String?,pid: freezed == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of PersistentWindow
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

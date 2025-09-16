// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'window_properties.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WindowProperties {

 String get appId; int? get pid; String? get title; String? get windowClass; String? get startupId;
/// Create a copy of WindowProperties
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WindowPropertiesCopyWith<WindowProperties> get copyWith => _$WindowPropertiesCopyWithImpl<WindowProperties>(this as WindowProperties, _$identity);

  /// Serializes this WindowProperties to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WindowProperties&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.title, title) || other.title == title)&&(identical(other.windowClass, windowClass) || other.windowClass == windowClass)&&(identical(other.startupId, startupId) || other.startupId == startupId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,appId,pid,title,windowClass,startupId);

@override
String toString() {
  return 'WindowProperties(appId: $appId, pid: $pid, title: $title, windowClass: $windowClass, startupId: $startupId)';
}


}

/// @nodoc
abstract mixin class $WindowPropertiesCopyWith<$Res>  {
  factory $WindowPropertiesCopyWith(WindowProperties value, $Res Function(WindowProperties) _then) = _$WindowPropertiesCopyWithImpl;
@useResult
$Res call({
 String appId, int? pid, String? title, String? windowClass, String? startupId
});




}
/// @nodoc
class _$WindowPropertiesCopyWithImpl<$Res>
    implements $WindowPropertiesCopyWith<$Res> {
  _$WindowPropertiesCopyWithImpl(this._self, this._then);

  final WindowProperties _self;
  final $Res Function(WindowProperties) _then;

/// Create a copy of WindowProperties
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? appId = null,Object? pid = freezed,Object? title = freezed,Object? windowClass = freezed,Object? startupId = freezed,}) {
  return _then(_self.copyWith(
appId: null == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String,pid: freezed == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,windowClass: freezed == windowClass ? _self.windowClass : windowClass // ignore: cast_nullable_to_non_nullable
as String?,startupId: freezed == startupId ? _self.startupId : startupId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WindowProperties].
extension WindowPropertiesPatterns on WindowProperties {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WindowProperties value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WindowProperties() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WindowProperties value)  $default,){
final _that = this;
switch (_that) {
case _WindowProperties():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WindowProperties value)?  $default,){
final _that = this;
switch (_that) {
case _WindowProperties() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String appId,  int? pid,  String? title,  String? windowClass,  String? startupId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WindowProperties() when $default != null:
return $default(_that.appId,_that.pid,_that.title,_that.windowClass,_that.startupId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String appId,  int? pid,  String? title,  String? windowClass,  String? startupId)  $default,) {final _that = this;
switch (_that) {
case _WindowProperties():
return $default(_that.appId,_that.pid,_that.title,_that.windowClass,_that.startupId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String appId,  int? pid,  String? title,  String? windowClass,  String? startupId)?  $default,) {final _that = this;
switch (_that) {
case _WindowProperties() when $default != null:
return $default(_that.appId,_that.pid,_that.title,_that.windowClass,_that.startupId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WindowProperties implements WindowProperties {
  const _WindowProperties({required this.appId, this.pid, this.title, this.windowClass, this.startupId});
  factory _WindowProperties.fromJson(Map<String, dynamic> json) => _$WindowPropertiesFromJson(json);

@override final  String appId;
@override final  int? pid;
@override final  String? title;
@override final  String? windowClass;
@override final  String? startupId;

/// Create a copy of WindowProperties
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WindowPropertiesCopyWith<_WindowProperties> get copyWith => __$WindowPropertiesCopyWithImpl<_WindowProperties>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WindowPropertiesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WindowProperties&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.title, title) || other.title == title)&&(identical(other.windowClass, windowClass) || other.windowClass == windowClass)&&(identical(other.startupId, startupId) || other.startupId == startupId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,appId,pid,title,windowClass,startupId);

@override
String toString() {
  return 'WindowProperties(appId: $appId, pid: $pid, title: $title, windowClass: $windowClass, startupId: $startupId)';
}


}

/// @nodoc
abstract mixin class _$WindowPropertiesCopyWith<$Res> implements $WindowPropertiesCopyWith<$Res> {
  factory _$WindowPropertiesCopyWith(_WindowProperties value, $Res Function(_WindowProperties) _then) = __$WindowPropertiesCopyWithImpl;
@override @useResult
$Res call({
 String appId, int? pid, String? title, String? windowClass, String? startupId
});




}
/// @nodoc
class __$WindowPropertiesCopyWithImpl<$Res>
    implements _$WindowPropertiesCopyWith<$Res> {
  __$WindowPropertiesCopyWithImpl(this._self, this._then);

  final _WindowProperties _self;
  final $Res Function(_WindowProperties) _then;

/// Create a copy of WindowProperties
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? appId = null,Object? pid = freezed,Object? title = freezed,Object? windowClass = freezed,Object? startupId = freezed,}) {
  return _then(_WindowProperties(
appId: null == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String,pid: freezed == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,windowClass: freezed == windowClass ? _self.windowClass : windowClass // ignore: cast_nullable_to_non_nullable
as String?,startupId: freezed == startupId ? _self.startupId : startupId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

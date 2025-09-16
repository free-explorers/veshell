// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'matching_info.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MatchingInfo {

 String get appId; String? get title; String? get windowClass; String? get startupId; int? get pid; DateTime? get waitingForAppSince;
/// Create a copy of MatchingInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchingInfoCopyWith<MatchingInfo> get copyWith => _$MatchingInfoCopyWithImpl<MatchingInfo>(this as MatchingInfo, _$identity);

  /// Serializes this MatchingInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchingInfo&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.title, title) || other.title == title)&&(identical(other.windowClass, windowClass) || other.windowClass == windowClass)&&(identical(other.startupId, startupId) || other.startupId == startupId)&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.waitingForAppSince, waitingForAppSince) || other.waitingForAppSince == waitingForAppSince));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,appId,title,windowClass,startupId,pid,waitingForAppSince);

@override
String toString() {
  return 'MatchingInfo(appId: $appId, title: $title, windowClass: $windowClass, startupId: $startupId, pid: $pid, waitingForAppSince: $waitingForAppSince)';
}


}

/// @nodoc
abstract mixin class $MatchingInfoCopyWith<$Res>  {
  factory $MatchingInfoCopyWith(MatchingInfo value, $Res Function(MatchingInfo) _then) = _$MatchingInfoCopyWithImpl;
@useResult
$Res call({
 String appId, String? title, String? windowClass, String? startupId, int? pid, DateTime? waitingForAppSince
});




}
/// @nodoc
class _$MatchingInfoCopyWithImpl<$Res>
    implements $MatchingInfoCopyWith<$Res> {
  _$MatchingInfoCopyWithImpl(this._self, this._then);

  final MatchingInfo _self;
  final $Res Function(MatchingInfo) _then;

/// Create a copy of MatchingInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? appId = null,Object? title = freezed,Object? windowClass = freezed,Object? startupId = freezed,Object? pid = freezed,Object? waitingForAppSince = freezed,}) {
  return _then(_self.copyWith(
appId: null == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,windowClass: freezed == windowClass ? _self.windowClass : windowClass // ignore: cast_nullable_to_non_nullable
as String?,startupId: freezed == startupId ? _self.startupId : startupId // ignore: cast_nullable_to_non_nullable
as String?,pid: freezed == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int?,waitingForAppSince: freezed == waitingForAppSince ? _self.waitingForAppSince : waitingForAppSince // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [MatchingInfo].
extension MatchingInfoPatterns on MatchingInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchingInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchingInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchingInfo value)  $default,){
final _that = this;
switch (_that) {
case _MatchingInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchingInfo value)?  $default,){
final _that = this;
switch (_that) {
case _MatchingInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String appId,  String? title,  String? windowClass,  String? startupId,  int? pid,  DateTime? waitingForAppSince)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatchingInfo() when $default != null:
return $default(_that.appId,_that.title,_that.windowClass,_that.startupId,_that.pid,_that.waitingForAppSince);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String appId,  String? title,  String? windowClass,  String? startupId,  int? pid,  DateTime? waitingForAppSince)  $default,) {final _that = this;
switch (_that) {
case _MatchingInfo():
return $default(_that.appId,_that.title,_that.windowClass,_that.startupId,_that.pid,_that.waitingForAppSince);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String appId,  String? title,  String? windowClass,  String? startupId,  int? pid,  DateTime? waitingForAppSince)?  $default,) {final _that = this;
switch (_that) {
case _MatchingInfo() when $default != null:
return $default(_that.appId,_that.title,_that.windowClass,_that.startupId,_that.pid,_that.waitingForAppSince);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatchingInfo implements MatchingInfo {
  const _MatchingInfo({required this.appId, this.title, this.windowClass, this.startupId, this.pid, this.waitingForAppSince});
  factory _MatchingInfo.fromJson(Map<String, dynamic> json) => _$MatchingInfoFromJson(json);

@override final  String appId;
@override final  String? title;
@override final  String? windowClass;
@override final  String? startupId;
@override final  int? pid;
@override final  DateTime? waitingForAppSince;

/// Create a copy of MatchingInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchingInfoCopyWith<_MatchingInfo> get copyWith => __$MatchingInfoCopyWithImpl<_MatchingInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatchingInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchingInfo&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.title, title) || other.title == title)&&(identical(other.windowClass, windowClass) || other.windowClass == windowClass)&&(identical(other.startupId, startupId) || other.startupId == startupId)&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.waitingForAppSince, waitingForAppSince) || other.waitingForAppSince == waitingForAppSince));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,appId,title,windowClass,startupId,pid,waitingForAppSince);

@override
String toString() {
  return 'MatchingInfo(appId: $appId, title: $title, windowClass: $windowClass, startupId: $startupId, pid: $pid, waitingForAppSince: $waitingForAppSince)';
}


}

/// @nodoc
abstract mixin class _$MatchingInfoCopyWith<$Res> implements $MatchingInfoCopyWith<$Res> {
  factory _$MatchingInfoCopyWith(_MatchingInfo value, $Res Function(_MatchingInfo) _then) = __$MatchingInfoCopyWithImpl;
@override @useResult
$Res call({
 String appId, String? title, String? windowClass, String? startupId, int? pid, DateTime? waitingForAppSince
});




}
/// @nodoc
class __$MatchingInfoCopyWithImpl<$Res>
    implements _$MatchingInfoCopyWith<$Res> {
  __$MatchingInfoCopyWithImpl(this._self, this._then);

  final _MatchingInfo _self;
  final $Res Function(_MatchingInfo) _then;

/// Create a copy of MatchingInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? appId = null,Object? title = freezed,Object? windowClass = freezed,Object? startupId = freezed,Object? pid = freezed,Object? waitingForAppSince = freezed,}) {
  return _then(_MatchingInfo(
appId: null == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,windowClass: freezed == windowClass ? _self.windowClass : windowClass // ignore: cast_nullable_to_non_nullable
as String?,startupId: freezed == startupId ? _self.startupId : startupId // ignore: cast_nullable_to_non_nullable
as String?,pid: freezed == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int?,waitingForAppSince: freezed == waitingForAppSince ? _self.waitingForAppSince : waitingForAppSince // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on

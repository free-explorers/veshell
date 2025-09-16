// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wifi_access_point.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WifiAccessPoint {

 String get ssid; List<NetworkManagerAccessPoint> get accessPoints; NetworkManagerSettingsConnection? get settingsConnection;
/// Create a copy of WifiAccessPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WifiAccessPointCopyWith<WifiAccessPoint> get copyWith => _$WifiAccessPointCopyWithImpl<WifiAccessPoint>(this as WifiAccessPoint, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WifiAccessPoint&&(identical(other.ssid, ssid) || other.ssid == ssid)&&const DeepCollectionEquality().equals(other.accessPoints, accessPoints)&&(identical(other.settingsConnection, settingsConnection) || other.settingsConnection == settingsConnection));
}


@override
int get hashCode => Object.hash(runtimeType,ssid,const DeepCollectionEquality().hash(accessPoints),settingsConnection);

@override
String toString() {
  return 'WifiAccessPoint(ssid: $ssid, accessPoints: $accessPoints, settingsConnection: $settingsConnection)';
}


}

/// @nodoc
abstract mixin class $WifiAccessPointCopyWith<$Res>  {
  factory $WifiAccessPointCopyWith(WifiAccessPoint value, $Res Function(WifiAccessPoint) _then) = _$WifiAccessPointCopyWithImpl;
@useResult
$Res call({
 String ssid, List<NetworkManagerAccessPoint> accessPoints, NetworkManagerSettingsConnection? settingsConnection
});




}
/// @nodoc
class _$WifiAccessPointCopyWithImpl<$Res>
    implements $WifiAccessPointCopyWith<$Res> {
  _$WifiAccessPointCopyWithImpl(this._self, this._then);

  final WifiAccessPoint _self;
  final $Res Function(WifiAccessPoint) _then;

/// Create a copy of WifiAccessPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ssid = null,Object? accessPoints = null,Object? settingsConnection = freezed,}) {
  return _then(_self.copyWith(
ssid: null == ssid ? _self.ssid : ssid // ignore: cast_nullable_to_non_nullable
as String,accessPoints: null == accessPoints ? _self.accessPoints : accessPoints // ignore: cast_nullable_to_non_nullable
as List<NetworkManagerAccessPoint>,settingsConnection: freezed == settingsConnection ? _self.settingsConnection : settingsConnection // ignore: cast_nullable_to_non_nullable
as NetworkManagerSettingsConnection?,
  ));
}

}


/// Adds pattern-matching-related methods to [WifiAccessPoint].
extension WifiAccessPointPatterns on WifiAccessPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WifiAccessPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WifiAccessPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WifiAccessPoint value)  $default,){
final _that = this;
switch (_that) {
case _WifiAccessPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WifiAccessPoint value)?  $default,){
final _that = this;
switch (_that) {
case _WifiAccessPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ssid,  List<NetworkManagerAccessPoint> accessPoints,  NetworkManagerSettingsConnection? settingsConnection)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WifiAccessPoint() when $default != null:
return $default(_that.ssid,_that.accessPoints,_that.settingsConnection);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ssid,  List<NetworkManagerAccessPoint> accessPoints,  NetworkManagerSettingsConnection? settingsConnection)  $default,) {final _that = this;
switch (_that) {
case _WifiAccessPoint():
return $default(_that.ssid,_that.accessPoints,_that.settingsConnection);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ssid,  List<NetworkManagerAccessPoint> accessPoints,  NetworkManagerSettingsConnection? settingsConnection)?  $default,) {final _that = this;
switch (_that) {
case _WifiAccessPoint() when $default != null:
return $default(_that.ssid,_that.accessPoints,_that.settingsConnection);case _:
  return null;

}
}

}

/// @nodoc


class _WifiAccessPoint extends WifiAccessPoint {
  const _WifiAccessPoint({required this.ssid, required final  List<NetworkManagerAccessPoint> accessPoints, this.settingsConnection}): _accessPoints = accessPoints,super._();
  

@override final  String ssid;
 final  List<NetworkManagerAccessPoint> _accessPoints;
@override List<NetworkManagerAccessPoint> get accessPoints {
  if (_accessPoints is EqualUnmodifiableListView) return _accessPoints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_accessPoints);
}

@override final  NetworkManagerSettingsConnection? settingsConnection;

/// Create a copy of WifiAccessPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WifiAccessPointCopyWith<_WifiAccessPoint> get copyWith => __$WifiAccessPointCopyWithImpl<_WifiAccessPoint>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WifiAccessPoint&&(identical(other.ssid, ssid) || other.ssid == ssid)&&const DeepCollectionEquality().equals(other._accessPoints, _accessPoints)&&(identical(other.settingsConnection, settingsConnection) || other.settingsConnection == settingsConnection));
}


@override
int get hashCode => Object.hash(runtimeType,ssid,const DeepCollectionEquality().hash(_accessPoints),settingsConnection);

@override
String toString() {
  return 'WifiAccessPoint(ssid: $ssid, accessPoints: $accessPoints, settingsConnection: $settingsConnection)';
}


}

/// @nodoc
abstract mixin class _$WifiAccessPointCopyWith<$Res> implements $WifiAccessPointCopyWith<$Res> {
  factory _$WifiAccessPointCopyWith(_WifiAccessPoint value, $Res Function(_WifiAccessPoint) _then) = __$WifiAccessPointCopyWithImpl;
@override @useResult
$Res call({
 String ssid, List<NetworkManagerAccessPoint> accessPoints, NetworkManagerSettingsConnection? settingsConnection
});




}
/// @nodoc
class __$WifiAccessPointCopyWithImpl<$Res>
    implements _$WifiAccessPointCopyWith<$Res> {
  __$WifiAccessPointCopyWithImpl(this._self, this._then);

  final _WifiAccessPoint _self;
  final $Res Function(_WifiAccessPoint) _then;

/// Create a copy of WifiAccessPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ssid = null,Object? accessPoints = null,Object? settingsConnection = freezed,}) {
  return _then(_WifiAccessPoint(
ssid: null == ssid ? _self.ssid : ssid // ignore: cast_nullable_to_non_nullable
as String,accessPoints: null == accessPoints ? _self._accessPoints : accessPoints // ignore: cast_nullable_to_non_nullable
as List<NetworkManagerAccessPoint>,settingsConnection: freezed == settingsConnection ? _self.settingsConnection : settingsConnection // ignore: cast_nullable_to_non_nullable
as NetworkManagerSettingsConnection?,
  ));
}


}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ethernet_device.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EthernetDevice {

 NetworkManagerDevice get nmDevice;
/// Create a copy of EthernetDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EthernetDeviceCopyWith<EthernetDevice> get copyWith => _$EthernetDeviceCopyWithImpl<EthernetDevice>(this as EthernetDevice, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EthernetDevice&&(identical(other.nmDevice, nmDevice) || other.nmDevice == nmDevice));
}


@override
int get hashCode => Object.hash(runtimeType,nmDevice);

@override
String toString() {
  return 'EthernetDevice(nmDevice: $nmDevice)';
}


}

/// @nodoc
abstract mixin class $EthernetDeviceCopyWith<$Res>  {
  factory $EthernetDeviceCopyWith(EthernetDevice value, $Res Function(EthernetDevice) _then) = _$EthernetDeviceCopyWithImpl;
@useResult
$Res call({
 NetworkManagerDevice nmDevice
});




}
/// @nodoc
class _$EthernetDeviceCopyWithImpl<$Res>
    implements $EthernetDeviceCopyWith<$Res> {
  _$EthernetDeviceCopyWithImpl(this._self, this._then);

  final EthernetDevice _self;
  final $Res Function(EthernetDevice) _then;

/// Create a copy of EthernetDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nmDevice = null,}) {
  return _then(_self.copyWith(
nmDevice: null == nmDevice ? _self.nmDevice : nmDevice // ignore: cast_nullable_to_non_nullable
as NetworkManagerDevice,
  ));
}

}


/// Adds pattern-matching-related methods to [EthernetDevice].
extension EthernetDevicePatterns on EthernetDevice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EthernetDevice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EthernetDevice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EthernetDevice value)  $default,){
final _that = this;
switch (_that) {
case _EthernetDevice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EthernetDevice value)?  $default,){
final _that = this;
switch (_that) {
case _EthernetDevice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( NetworkManagerDevice nmDevice)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EthernetDevice() when $default != null:
return $default(_that.nmDevice);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( NetworkManagerDevice nmDevice)  $default,) {final _that = this;
switch (_that) {
case _EthernetDevice():
return $default(_that.nmDevice);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( NetworkManagerDevice nmDevice)?  $default,) {final _that = this;
switch (_that) {
case _EthernetDevice() when $default != null:
return $default(_that.nmDevice);case _:
  return null;

}
}

}

/// @nodoc


class _EthernetDevice implements EthernetDevice {
   _EthernetDevice({required this.nmDevice});
  

@override final  NetworkManagerDevice nmDevice;

/// Create a copy of EthernetDevice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EthernetDeviceCopyWith<_EthernetDevice> get copyWith => __$EthernetDeviceCopyWithImpl<_EthernetDevice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EthernetDevice&&(identical(other.nmDevice, nmDevice) || other.nmDevice == nmDevice));
}


@override
int get hashCode => Object.hash(runtimeType,nmDevice);

@override
String toString() {
  return 'EthernetDevice(nmDevice: $nmDevice)';
}


}

/// @nodoc
abstract mixin class _$EthernetDeviceCopyWith<$Res> implements $EthernetDeviceCopyWith<$Res> {
  factory _$EthernetDeviceCopyWith(_EthernetDevice value, $Res Function(_EthernetDevice) _then) = __$EthernetDeviceCopyWithImpl;
@override @useResult
$Res call({
 NetworkManagerDevice nmDevice
});




}
/// @nodoc
class __$EthernetDeviceCopyWithImpl<$Res>
    implements _$EthernetDeviceCopyWith<$Res> {
  __$EthernetDeviceCopyWithImpl(this._self, this._then);

  final _EthernetDevice _self;
  final $Res Function(_EthernetDevice) _then;

/// Create a copy of EthernetDevice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nmDevice = null,}) {
  return _then(_EthernetDevice(
nmDevice: null == nmDevice ? _self.nmDevice : nmDevice // ignore: cast_nullable_to_non_nullable
as NetworkManagerDevice,
  ));
}


}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bluetooth_device.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BluetoothDevice {

 BlueZDevice get bluezDevice; bool get connecting; bool get pairing;
/// Create a copy of BluetoothDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BluetoothDeviceCopyWith<BluetoothDevice> get copyWith => _$BluetoothDeviceCopyWithImpl<BluetoothDevice>(this as BluetoothDevice, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BluetoothDevice&&(identical(other.bluezDevice, bluezDevice) || other.bluezDevice == bluezDevice)&&(identical(other.connecting, connecting) || other.connecting == connecting)&&(identical(other.pairing, pairing) || other.pairing == pairing));
}


@override
int get hashCode => Object.hash(runtimeType,bluezDevice,connecting,pairing);

@override
String toString() {
  return 'BluetoothDevice(bluezDevice: $bluezDevice, connecting: $connecting, pairing: $pairing)';
}


}

/// @nodoc
abstract mixin class $BluetoothDeviceCopyWith<$Res>  {
  factory $BluetoothDeviceCopyWith(BluetoothDevice value, $Res Function(BluetoothDevice) _then) = _$BluetoothDeviceCopyWithImpl;
@useResult
$Res call({
 BlueZDevice bluezDevice, bool connecting, bool pairing
});




}
/// @nodoc
class _$BluetoothDeviceCopyWithImpl<$Res>
    implements $BluetoothDeviceCopyWith<$Res> {
  _$BluetoothDeviceCopyWithImpl(this._self, this._then);

  final BluetoothDevice _self;
  final $Res Function(BluetoothDevice) _then;

/// Create a copy of BluetoothDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bluezDevice = null,Object? connecting = null,Object? pairing = null,}) {
  return _then(_self.copyWith(
bluezDevice: null == bluezDevice ? _self.bluezDevice : bluezDevice // ignore: cast_nullable_to_non_nullable
as BlueZDevice,connecting: null == connecting ? _self.connecting : connecting // ignore: cast_nullable_to_non_nullable
as bool,pairing: null == pairing ? _self.pairing : pairing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BluetoothDevice].
extension BluetoothDevicePatterns on BluetoothDevice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BluetoothDevice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BluetoothDevice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BluetoothDevice value)  $default,){
final _that = this;
switch (_that) {
case _BluetoothDevice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BluetoothDevice value)?  $default,){
final _that = this;
switch (_that) {
case _BluetoothDevice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BlueZDevice bluezDevice,  bool connecting,  bool pairing)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BluetoothDevice() when $default != null:
return $default(_that.bluezDevice,_that.connecting,_that.pairing);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BlueZDevice bluezDevice,  bool connecting,  bool pairing)  $default,) {final _that = this;
switch (_that) {
case _BluetoothDevice():
return $default(_that.bluezDevice,_that.connecting,_that.pairing);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BlueZDevice bluezDevice,  bool connecting,  bool pairing)?  $default,) {final _that = this;
switch (_that) {
case _BluetoothDevice() when $default != null:
return $default(_that.bluezDevice,_that.connecting,_that.pairing);case _:
  return null;

}
}

}

/// @nodoc


class _BluetoothDevice implements BluetoothDevice {
   _BluetoothDevice({required this.bluezDevice, required this.connecting, required this.pairing});
  

@override final  BlueZDevice bluezDevice;
@override final  bool connecting;
@override final  bool pairing;

/// Create a copy of BluetoothDevice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BluetoothDeviceCopyWith<_BluetoothDevice> get copyWith => __$BluetoothDeviceCopyWithImpl<_BluetoothDevice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BluetoothDevice&&(identical(other.bluezDevice, bluezDevice) || other.bluezDevice == bluezDevice)&&(identical(other.connecting, connecting) || other.connecting == connecting)&&(identical(other.pairing, pairing) || other.pairing == pairing));
}


@override
int get hashCode => Object.hash(runtimeType,bluezDevice,connecting,pairing);

@override
String toString() {
  return 'BluetoothDevice(bluezDevice: $bluezDevice, connecting: $connecting, pairing: $pairing)';
}


}

/// @nodoc
abstract mixin class _$BluetoothDeviceCopyWith<$Res> implements $BluetoothDeviceCopyWith<$Res> {
  factory _$BluetoothDeviceCopyWith(_BluetoothDevice value, $Res Function(_BluetoothDevice) _then) = __$BluetoothDeviceCopyWithImpl;
@override @useResult
$Res call({
 BlueZDevice bluezDevice, bool connecting, bool pairing
});




}
/// @nodoc
class __$BluetoothDeviceCopyWithImpl<$Res>
    implements _$BluetoothDeviceCopyWith<$Res> {
  __$BluetoothDeviceCopyWithImpl(this._self, this._then);

  final _BluetoothDevice _self;
  final $Res Function(_BluetoothDevice) _then;

/// Create a copy of BluetoothDevice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bluezDevice = null,Object? connecting = null,Object? pairing = null,}) {
  return _then(_BluetoothDevice(
bluezDevice: null == bluezDevice ? _self.bluezDevice : bluezDevice // ignore: cast_nullable_to_non_nullable
as BlueZDevice,connecting: null == connecting ? _self.connecting : connecting // ignore: cast_nullable_to_non_nullable
as bool,pairing: null == pairing ? _self.pairing : pairing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

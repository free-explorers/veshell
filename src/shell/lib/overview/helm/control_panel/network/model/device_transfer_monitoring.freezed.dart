// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_transfer_monitoring.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DeviceTransferMonitoring {

 int get receivingBytesPerSecond; int get transferringBytesPerSecond;
/// Create a copy of DeviceTransferMonitoring
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceTransferMonitoringCopyWith<DeviceTransferMonitoring> get copyWith => _$DeviceTransferMonitoringCopyWithImpl<DeviceTransferMonitoring>(this as DeviceTransferMonitoring, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceTransferMonitoring&&(identical(other.receivingBytesPerSecond, receivingBytesPerSecond) || other.receivingBytesPerSecond == receivingBytesPerSecond)&&(identical(other.transferringBytesPerSecond, transferringBytesPerSecond) || other.transferringBytesPerSecond == transferringBytesPerSecond));
}


@override
int get hashCode => Object.hash(runtimeType,receivingBytesPerSecond,transferringBytesPerSecond);

@override
String toString() {
  return 'DeviceTransferMonitoring(receivingBytesPerSecond: $receivingBytesPerSecond, transferringBytesPerSecond: $transferringBytesPerSecond)';
}


}

/// @nodoc
abstract mixin class $DeviceTransferMonitoringCopyWith<$Res>  {
  factory $DeviceTransferMonitoringCopyWith(DeviceTransferMonitoring value, $Res Function(DeviceTransferMonitoring) _then) = _$DeviceTransferMonitoringCopyWithImpl;
@useResult
$Res call({
 int receivingBytesPerSecond, int transferringBytesPerSecond
});




}
/// @nodoc
class _$DeviceTransferMonitoringCopyWithImpl<$Res>
    implements $DeviceTransferMonitoringCopyWith<$Res> {
  _$DeviceTransferMonitoringCopyWithImpl(this._self, this._then);

  final DeviceTransferMonitoring _self;
  final $Res Function(DeviceTransferMonitoring) _then;

/// Create a copy of DeviceTransferMonitoring
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? receivingBytesPerSecond = null,Object? transferringBytesPerSecond = null,}) {
  return _then(_self.copyWith(
receivingBytesPerSecond: null == receivingBytesPerSecond ? _self.receivingBytesPerSecond : receivingBytesPerSecond // ignore: cast_nullable_to_non_nullable
as int,transferringBytesPerSecond: null == transferringBytesPerSecond ? _self.transferringBytesPerSecond : transferringBytesPerSecond // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceTransferMonitoring].
extension DeviceTransferMonitoringPatterns on DeviceTransferMonitoring {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceTransferMonitoring value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceTransferMonitoring() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceTransferMonitoring value)  $default,){
final _that = this;
switch (_that) {
case _DeviceTransferMonitoring():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceTransferMonitoring value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceTransferMonitoring() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int receivingBytesPerSecond,  int transferringBytesPerSecond)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceTransferMonitoring() when $default != null:
return $default(_that.receivingBytesPerSecond,_that.transferringBytesPerSecond);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int receivingBytesPerSecond,  int transferringBytesPerSecond)  $default,) {final _that = this;
switch (_that) {
case _DeviceTransferMonitoring():
return $default(_that.receivingBytesPerSecond,_that.transferringBytesPerSecond);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int receivingBytesPerSecond,  int transferringBytesPerSecond)?  $default,) {final _that = this;
switch (_that) {
case _DeviceTransferMonitoring() when $default != null:
return $default(_that.receivingBytesPerSecond,_that.transferringBytesPerSecond);case _:
  return null;

}
}

}

/// @nodoc


class _DeviceTransferMonitoring implements DeviceTransferMonitoring {
   _DeviceTransferMonitoring({required this.receivingBytesPerSecond, required this.transferringBytesPerSecond});
  

@override final  int receivingBytesPerSecond;
@override final  int transferringBytesPerSecond;

/// Create a copy of DeviceTransferMonitoring
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceTransferMonitoringCopyWith<_DeviceTransferMonitoring> get copyWith => __$DeviceTransferMonitoringCopyWithImpl<_DeviceTransferMonitoring>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceTransferMonitoring&&(identical(other.receivingBytesPerSecond, receivingBytesPerSecond) || other.receivingBytesPerSecond == receivingBytesPerSecond)&&(identical(other.transferringBytesPerSecond, transferringBytesPerSecond) || other.transferringBytesPerSecond == transferringBytesPerSecond));
}


@override
int get hashCode => Object.hash(runtimeType,receivingBytesPerSecond,transferringBytesPerSecond);

@override
String toString() {
  return 'DeviceTransferMonitoring(receivingBytesPerSecond: $receivingBytesPerSecond, transferringBytesPerSecond: $transferringBytesPerSecond)';
}


}

/// @nodoc
abstract mixin class _$DeviceTransferMonitoringCopyWith<$Res> implements $DeviceTransferMonitoringCopyWith<$Res> {
  factory _$DeviceTransferMonitoringCopyWith(_DeviceTransferMonitoring value, $Res Function(_DeviceTransferMonitoring) _then) = __$DeviceTransferMonitoringCopyWithImpl;
@override @useResult
$Res call({
 int receivingBytesPerSecond, int transferringBytesPerSecond
});




}
/// @nodoc
class __$DeviceTransferMonitoringCopyWithImpl<$Res>
    implements _$DeviceTransferMonitoringCopyWith<$Res> {
  __$DeviceTransferMonitoringCopyWithImpl(this._self, this._then);

  final _DeviceTransferMonitoring _self;
  final $Res Function(_DeviceTransferMonitoring) _then;

/// Create a copy of DeviceTransferMonitoring
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? receivingBytesPerSecond = null,Object? transferringBytesPerSecond = null,}) {
  return _then(_DeviceTransferMonitoring(
receivingBytesPerSecond: null == receivingBytesPerSecond ? _self.receivingBytesPerSecond : receivingBytesPerSecond // ignore: cast_nullable_to_non_nullable
as int,transferringBytesPerSecond: null == transferringBytesPerSecond ? _self.transferringBytesPerSecond : transferringBytesPerSecond // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

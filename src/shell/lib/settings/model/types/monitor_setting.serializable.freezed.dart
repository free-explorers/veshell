// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monitor_setting.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MonitorSetting {

 Mode get mode; double get fractionnalScale;@OffsetIntConverter() Offset get location;
/// Create a copy of MonitorSetting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MonitorSettingCopyWith<MonitorSetting> get copyWith => _$MonitorSettingCopyWithImpl<MonitorSetting>(this as MonitorSetting, _$identity);

  /// Serializes this MonitorSetting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MonitorSetting&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.fractionnalScale, fractionnalScale) || other.fractionnalScale == fractionnalScale)&&(identical(other.location, location) || other.location == location));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mode,fractionnalScale,location);

@override
String toString() {
  return 'MonitorSetting(mode: $mode, fractionnalScale: $fractionnalScale, location: $location)';
}


}

/// @nodoc
abstract mixin class $MonitorSettingCopyWith<$Res>  {
  factory $MonitorSettingCopyWith(MonitorSetting value, $Res Function(MonitorSetting) _then) = _$MonitorSettingCopyWithImpl;
@useResult
$Res call({
 Mode mode, double fractionnalScale,@OffsetIntConverter() Offset location
});


$ModeCopyWith<$Res> get mode;

}
/// @nodoc
class _$MonitorSettingCopyWithImpl<$Res>
    implements $MonitorSettingCopyWith<$Res> {
  _$MonitorSettingCopyWithImpl(this._self, this._then);

  final MonitorSetting _self;
  final $Res Function(MonitorSetting) _then;

/// Create a copy of MonitorSetting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mode = null,Object? fractionnalScale = null,Object? location = null,}) {
  return _then(_self.copyWith(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as Mode,fractionnalScale: null == fractionnalScale ? _self.fractionnalScale : fractionnalScale // ignore: cast_nullable_to_non_nullable
as double,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as Offset,
  ));
}
/// Create a copy of MonitorSetting
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModeCopyWith<$Res> get mode {
  
  return $ModeCopyWith<$Res>(_self.mode, (value) {
    return _then(_self.copyWith(mode: value));
  });
}
}


/// Adds pattern-matching-related methods to [MonitorSetting].
extension MonitorSettingPatterns on MonitorSetting {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MonitorSetting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MonitorSetting() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MonitorSetting value)  $default,){
final _that = this;
switch (_that) {
case _MonitorSetting():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MonitorSetting value)?  $default,){
final _that = this;
switch (_that) {
case _MonitorSetting() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Mode mode,  double fractionnalScale, @OffsetIntConverter()  Offset location)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MonitorSetting() when $default != null:
return $default(_that.mode,_that.fractionnalScale,_that.location);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Mode mode,  double fractionnalScale, @OffsetIntConverter()  Offset location)  $default,) {final _that = this;
switch (_that) {
case _MonitorSetting():
return $default(_that.mode,_that.fractionnalScale,_that.location);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Mode mode,  double fractionnalScale, @OffsetIntConverter()  Offset location)?  $default,) {final _that = this;
switch (_that) {
case _MonitorSetting() when $default != null:
return $default(_that.mode,_that.fractionnalScale,_that.location);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MonitorSetting implements MonitorSetting {
  const _MonitorSetting({required this.mode, required this.fractionnalScale, @OffsetIntConverter() required this.location});
  factory _MonitorSetting.fromJson(Map<String, dynamic> json) => _$MonitorSettingFromJson(json);

@override final  Mode mode;
@override final  double fractionnalScale;
@override@OffsetIntConverter() final  Offset location;

/// Create a copy of MonitorSetting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MonitorSettingCopyWith<_MonitorSetting> get copyWith => __$MonitorSettingCopyWithImpl<_MonitorSetting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MonitorSettingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MonitorSetting&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.fractionnalScale, fractionnalScale) || other.fractionnalScale == fractionnalScale)&&(identical(other.location, location) || other.location == location));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mode,fractionnalScale,location);

@override
String toString() {
  return 'MonitorSetting(mode: $mode, fractionnalScale: $fractionnalScale, location: $location)';
}


}

/// @nodoc
abstract mixin class _$MonitorSettingCopyWith<$Res> implements $MonitorSettingCopyWith<$Res> {
  factory _$MonitorSettingCopyWith(_MonitorSetting value, $Res Function(_MonitorSetting) _then) = __$MonitorSettingCopyWithImpl;
@override @useResult
$Res call({
 Mode mode, double fractionnalScale,@OffsetIntConverter() Offset location
});


@override $ModeCopyWith<$Res> get mode;

}
/// @nodoc
class __$MonitorSettingCopyWithImpl<$Res>
    implements _$MonitorSettingCopyWith<$Res> {
  __$MonitorSettingCopyWithImpl(this._self, this._then);

  final _MonitorSetting _self;
  final $Res Function(_MonitorSetting) _then;

/// Create a copy of MonitorSetting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? fractionnalScale = null,Object? location = null,}) {
  return _then(_MonitorSetting(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as Mode,fractionnalScale: null == fractionnalScale ? _self.fractionnalScale : fractionnalScale // ignore: cast_nullable_to_non_nullable
as double,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as Offset,
  ));
}

/// Create a copy of MonitorSetting
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModeCopyWith<$Res> get mode {
  
  return $ModeCopyWith<$Res>(_self.mode, (value) {
    return _then(_self.copyWith(mode: value));
  });
}
}

// dart format on

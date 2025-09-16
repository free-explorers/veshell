// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'screen_configuration.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ScreenConfiguration {

 int get flex; ScreenId get screenId; MonitorId? get primaryForMonitor;
/// Create a copy of ScreenConfiguration
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScreenConfigurationCopyWith<ScreenConfiguration> get copyWith => _$ScreenConfigurationCopyWithImpl<ScreenConfiguration>(this as ScreenConfiguration, _$identity);

  /// Serializes this ScreenConfiguration to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScreenConfiguration&&(identical(other.flex, flex) || other.flex == flex)&&(identical(other.screenId, screenId) || other.screenId == screenId)&&(identical(other.primaryForMonitor, primaryForMonitor) || other.primaryForMonitor == primaryForMonitor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,flex,screenId,primaryForMonitor);

@override
String toString() {
  return 'ScreenConfiguration(flex: $flex, screenId: $screenId, primaryForMonitor: $primaryForMonitor)';
}


}

/// @nodoc
abstract mixin class $ScreenConfigurationCopyWith<$Res>  {
  factory $ScreenConfigurationCopyWith(ScreenConfiguration value, $Res Function(ScreenConfiguration) _then) = _$ScreenConfigurationCopyWithImpl;
@useResult
$Res call({
 int flex, ScreenId screenId, MonitorId? primaryForMonitor
});




}
/// @nodoc
class _$ScreenConfigurationCopyWithImpl<$Res>
    implements $ScreenConfigurationCopyWith<$Res> {
  _$ScreenConfigurationCopyWithImpl(this._self, this._then);

  final ScreenConfiguration _self;
  final $Res Function(ScreenConfiguration) _then;

/// Create a copy of ScreenConfiguration
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? flex = null,Object? screenId = null,Object? primaryForMonitor = freezed,}) {
  return _then(_self.copyWith(
flex: null == flex ? _self.flex : flex // ignore: cast_nullable_to_non_nullable
as int,screenId: null == screenId ? _self.screenId : screenId // ignore: cast_nullable_to_non_nullable
as ScreenId,primaryForMonitor: freezed == primaryForMonitor ? _self.primaryForMonitor : primaryForMonitor // ignore: cast_nullable_to_non_nullable
as MonitorId?,
  ));
}

}


/// Adds pattern-matching-related methods to [ScreenConfiguration].
extension ScreenConfigurationPatterns on ScreenConfiguration {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScreenConfiguration value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScreenConfiguration() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScreenConfiguration value)  $default,){
final _that = this;
switch (_that) {
case _ScreenConfiguration():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScreenConfiguration value)?  $default,){
final _that = this;
switch (_that) {
case _ScreenConfiguration() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int flex,  ScreenId screenId,  MonitorId? primaryForMonitor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScreenConfiguration() when $default != null:
return $default(_that.flex,_that.screenId,_that.primaryForMonitor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int flex,  ScreenId screenId,  MonitorId? primaryForMonitor)  $default,) {final _that = this;
switch (_that) {
case _ScreenConfiguration():
return $default(_that.flex,_that.screenId,_that.primaryForMonitor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int flex,  ScreenId screenId,  MonitorId? primaryForMonitor)?  $default,) {final _that = this;
switch (_that) {
case _ScreenConfiguration() when $default != null:
return $default(_that.flex,_that.screenId,_that.primaryForMonitor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ScreenConfiguration implements ScreenConfiguration {
  const _ScreenConfiguration({required this.flex, required this.screenId, this.primaryForMonitor});
  factory _ScreenConfiguration.fromJson(Map<String, dynamic> json) => _$ScreenConfigurationFromJson(json);

@override final  int flex;
@override final  ScreenId screenId;
@override final  MonitorId? primaryForMonitor;

/// Create a copy of ScreenConfiguration
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScreenConfigurationCopyWith<_ScreenConfiguration> get copyWith => __$ScreenConfigurationCopyWithImpl<_ScreenConfiguration>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScreenConfigurationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScreenConfiguration&&(identical(other.flex, flex) || other.flex == flex)&&(identical(other.screenId, screenId) || other.screenId == screenId)&&(identical(other.primaryForMonitor, primaryForMonitor) || other.primaryForMonitor == primaryForMonitor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,flex,screenId,primaryForMonitor);

@override
String toString() {
  return 'ScreenConfiguration(flex: $flex, screenId: $screenId, primaryForMonitor: $primaryForMonitor)';
}


}

/// @nodoc
abstract mixin class _$ScreenConfigurationCopyWith<$Res> implements $ScreenConfigurationCopyWith<$Res> {
  factory _$ScreenConfigurationCopyWith(_ScreenConfiguration value, $Res Function(_ScreenConfiguration) _then) = __$ScreenConfigurationCopyWithImpl;
@override @useResult
$Res call({
 int flex, ScreenId screenId, MonitorId? primaryForMonitor
});




}
/// @nodoc
class __$ScreenConfigurationCopyWithImpl<$Res>
    implements _$ScreenConfigurationCopyWith<$Res> {
  __$ScreenConfigurationCopyWithImpl(this._self, this._then);

  final _ScreenConfiguration _self;
  final $Res Function(_ScreenConfiguration) _then;

/// Create a copy of ScreenConfiguration
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? flex = null,Object? screenId = null,Object? primaryForMonitor = freezed,}) {
  return _then(_ScreenConfiguration(
flex: null == flex ? _self.flex : flex // ignore: cast_nullable_to_non_nullable
as int,screenId: null == screenId ? _self.screenId : screenId // ignore: cast_nullable_to_non_nullable
as ScreenId,primaryForMonitor: freezed == primaryForMonitor ? _self.primaryForMonitor : primaryForMonitor // ignore: cast_nullable_to_non_nullable
as MonitorId?,
  ));
}


}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monitor_configuration.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MonitorConfiguration {

 IList<ScreenConfiguration> get screenList; ScreenDisplayMode get displayMode;
/// Create a copy of MonitorConfiguration
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MonitorConfigurationCopyWith<MonitorConfiguration> get copyWith => _$MonitorConfigurationCopyWithImpl<MonitorConfiguration>(this as MonitorConfiguration, _$identity);

  /// Serializes this MonitorConfiguration to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MonitorConfiguration&&const DeepCollectionEquality().equals(other.screenList, screenList)&&(identical(other.displayMode, displayMode) || other.displayMode == displayMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(screenList),displayMode);

@override
String toString() {
  return 'MonitorConfiguration(screenList: $screenList, displayMode: $displayMode)';
}


}

/// @nodoc
abstract mixin class $MonitorConfigurationCopyWith<$Res>  {
  factory $MonitorConfigurationCopyWith(MonitorConfiguration value, $Res Function(MonitorConfiguration) _then) = _$MonitorConfigurationCopyWithImpl;
@useResult
$Res call({
 IList<ScreenConfiguration> screenList, ScreenDisplayMode displayMode
});




}
/// @nodoc
class _$MonitorConfigurationCopyWithImpl<$Res>
    implements $MonitorConfigurationCopyWith<$Res> {
  _$MonitorConfigurationCopyWithImpl(this._self, this._then);

  final MonitorConfiguration _self;
  final $Res Function(MonitorConfiguration) _then;

/// Create a copy of MonitorConfiguration
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? screenList = null,Object? displayMode = null,}) {
  return _then(_self.copyWith(
screenList: null == screenList ? _self.screenList : screenList // ignore: cast_nullable_to_non_nullable
as IList<ScreenConfiguration>,displayMode: null == displayMode ? _self.displayMode : displayMode // ignore: cast_nullable_to_non_nullable
as ScreenDisplayMode,
  ));
}

}


/// Adds pattern-matching-related methods to [MonitorConfiguration].
extension MonitorConfigurationPatterns on MonitorConfiguration {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MonitorConfiguration value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MonitorConfiguration() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MonitorConfiguration value)  $default,){
final _that = this;
switch (_that) {
case _MonitorConfiguration():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MonitorConfiguration value)?  $default,){
final _that = this;
switch (_that) {
case _MonitorConfiguration() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IList<ScreenConfiguration> screenList,  ScreenDisplayMode displayMode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MonitorConfiguration() when $default != null:
return $default(_that.screenList,_that.displayMode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IList<ScreenConfiguration> screenList,  ScreenDisplayMode displayMode)  $default,) {final _that = this;
switch (_that) {
case _MonitorConfiguration():
return $default(_that.screenList,_that.displayMode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IList<ScreenConfiguration> screenList,  ScreenDisplayMode displayMode)?  $default,) {final _that = this;
switch (_that) {
case _MonitorConfiguration() when $default != null:
return $default(_that.screenList,_that.displayMode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MonitorConfiguration extends MonitorConfiguration {
   _MonitorConfiguration({required this.screenList, required this.displayMode}): super._();
  factory _MonitorConfiguration.fromJson(Map<String, dynamic> json) => _$MonitorConfigurationFromJson(json);

@override final  IList<ScreenConfiguration> screenList;
@override final  ScreenDisplayMode displayMode;

/// Create a copy of MonitorConfiguration
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MonitorConfigurationCopyWith<_MonitorConfiguration> get copyWith => __$MonitorConfigurationCopyWithImpl<_MonitorConfiguration>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MonitorConfigurationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MonitorConfiguration&&const DeepCollectionEquality().equals(other.screenList, screenList)&&(identical(other.displayMode, displayMode) || other.displayMode == displayMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(screenList),displayMode);

@override
String toString() {
  return 'MonitorConfiguration(screenList: $screenList, displayMode: $displayMode)';
}


}

/// @nodoc
abstract mixin class _$MonitorConfigurationCopyWith<$Res> implements $MonitorConfigurationCopyWith<$Res> {
  factory _$MonitorConfigurationCopyWith(_MonitorConfiguration value, $Res Function(_MonitorConfiguration) _then) = __$MonitorConfigurationCopyWithImpl;
@override @useResult
$Res call({
 IList<ScreenConfiguration> screenList, ScreenDisplayMode displayMode
});




}
/// @nodoc
class __$MonitorConfigurationCopyWithImpl<$Res>
    implements _$MonitorConfigurationCopyWith<$Res> {
  __$MonitorConfigurationCopyWithImpl(this._self, this._then);

  final _MonitorConfiguration _self;
  final $Res Function(_MonitorConfiguration) _then;

/// Create a copy of MonitorConfiguration
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? screenList = null,Object? displayMode = null,}) {
  return _then(_MonitorConfiguration(
screenList: null == screenList ? _self.screenList : screenList // ignore: cast_nullable_to_non_nullable
as IList<ScreenConfiguration>,displayMode: null == displayMode ? _self.displayMode : displayMode // ignore: cast_nullable_to_non_nullable
as ScreenDisplayMode,
  ));
}


}

// dart format on

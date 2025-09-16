// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'launch_config.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LaunchConfig {

 String get command; List<String> get arguments; bool get useDedicatedGpu;
/// Create a copy of LaunchConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LaunchConfigCopyWith<LaunchConfig> get copyWith => _$LaunchConfigCopyWithImpl<LaunchConfig>(this as LaunchConfig, _$identity);

  /// Serializes this LaunchConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LaunchConfig&&(identical(other.command, command) || other.command == command)&&const DeepCollectionEquality().equals(other.arguments, arguments)&&(identical(other.useDedicatedGpu, useDedicatedGpu) || other.useDedicatedGpu == useDedicatedGpu));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,command,const DeepCollectionEquality().hash(arguments),useDedicatedGpu);

@override
String toString() {
  return 'LaunchConfig(command: $command, arguments: $arguments, useDedicatedGpu: $useDedicatedGpu)';
}


}

/// @nodoc
abstract mixin class $LaunchConfigCopyWith<$Res>  {
  factory $LaunchConfigCopyWith(LaunchConfig value, $Res Function(LaunchConfig) _then) = _$LaunchConfigCopyWithImpl;
@useResult
$Res call({
 String command, List<String> arguments, bool useDedicatedGpu
});




}
/// @nodoc
class _$LaunchConfigCopyWithImpl<$Res>
    implements $LaunchConfigCopyWith<$Res> {
  _$LaunchConfigCopyWithImpl(this._self, this._then);

  final LaunchConfig _self;
  final $Res Function(LaunchConfig) _then;

/// Create a copy of LaunchConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? command = null,Object? arguments = null,Object? useDedicatedGpu = null,}) {
  return _then(_self.copyWith(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,arguments: null == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as List<String>,useDedicatedGpu: null == useDedicatedGpu ? _self.useDedicatedGpu : useDedicatedGpu // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LaunchConfig].
extension LaunchConfigPatterns on LaunchConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LaunchConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LaunchConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LaunchConfig value)  $default,){
final _that = this;
switch (_that) {
case _LaunchConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LaunchConfig value)?  $default,){
final _that = this;
switch (_that) {
case _LaunchConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String command,  List<String> arguments,  bool useDedicatedGpu)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LaunchConfig() when $default != null:
return $default(_that.command,_that.arguments,_that.useDedicatedGpu);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String command,  List<String> arguments,  bool useDedicatedGpu)  $default,) {final _that = this;
switch (_that) {
case _LaunchConfig():
return $default(_that.command,_that.arguments,_that.useDedicatedGpu);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String command,  List<String> arguments,  bool useDedicatedGpu)?  $default,) {final _that = this;
switch (_that) {
case _LaunchConfig() when $default != null:
return $default(_that.command,_that.arguments,_that.useDedicatedGpu);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LaunchConfig implements LaunchConfig {
  const _LaunchConfig({required this.command, final  List<String> arguments = const [], this.useDedicatedGpu = false}): _arguments = arguments;
  factory _LaunchConfig.fromJson(Map<String, dynamic> json) => _$LaunchConfigFromJson(json);

@override final  String command;
 final  List<String> _arguments;
@override@JsonKey() List<String> get arguments {
  if (_arguments is EqualUnmodifiableListView) return _arguments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_arguments);
}

@override@JsonKey() final  bool useDedicatedGpu;

/// Create a copy of LaunchConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LaunchConfigCopyWith<_LaunchConfig> get copyWith => __$LaunchConfigCopyWithImpl<_LaunchConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LaunchConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LaunchConfig&&(identical(other.command, command) || other.command == command)&&const DeepCollectionEquality().equals(other._arguments, _arguments)&&(identical(other.useDedicatedGpu, useDedicatedGpu) || other.useDedicatedGpu == useDedicatedGpu));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,command,const DeepCollectionEquality().hash(_arguments),useDedicatedGpu);

@override
String toString() {
  return 'LaunchConfig(command: $command, arguments: $arguments, useDedicatedGpu: $useDedicatedGpu)';
}


}

/// @nodoc
abstract mixin class _$LaunchConfigCopyWith<$Res> implements $LaunchConfigCopyWith<$Res> {
  factory _$LaunchConfigCopyWith(_LaunchConfig value, $Res Function(_LaunchConfig) _then) = __$LaunchConfigCopyWithImpl;
@override @useResult
$Res call({
 String command, List<String> arguments, bool useDedicatedGpu
});




}
/// @nodoc
class __$LaunchConfigCopyWithImpl<$Res>
    implements _$LaunchConfigCopyWith<$Res> {
  __$LaunchConfigCopyWithImpl(this._self, this._then);

  final _LaunchConfig _self;
  final $Res Function(_LaunchConfig) _then;

/// Create a copy of LaunchConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? command = null,Object? arguments = null,Object? useDedicatedGpu = null,}) {
  return _then(_LaunchConfig(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,arguments: null == arguments ? _self._arguments : arguments // ignore: cast_nullable_to_non_nullable
as List<String>,useDedicatedGpu: null == useDedicatedGpu ? _self.useDedicatedGpu : useDedicatedGpu // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

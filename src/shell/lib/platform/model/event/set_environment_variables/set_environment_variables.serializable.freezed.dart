// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'set_environment_variables.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SetEnvironmentVariablesMessage {

/// A nullable value means that the variable should be unset.
 IMap<String, String?> get environmentVariables;
/// Create a copy of SetEnvironmentVariablesMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetEnvironmentVariablesMessageCopyWith<SetEnvironmentVariablesMessage> get copyWith => _$SetEnvironmentVariablesMessageCopyWithImpl<SetEnvironmentVariablesMessage>(this as SetEnvironmentVariablesMessage, _$identity);

  /// Serializes this SetEnvironmentVariablesMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetEnvironmentVariablesMessage&&(identical(other.environmentVariables, environmentVariables) || other.environmentVariables == environmentVariables));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,environmentVariables);

@override
String toString() {
  return 'SetEnvironmentVariablesMessage(environmentVariables: $environmentVariables)';
}


}

/// @nodoc
abstract mixin class $SetEnvironmentVariablesMessageCopyWith<$Res>  {
  factory $SetEnvironmentVariablesMessageCopyWith(SetEnvironmentVariablesMessage value, $Res Function(SetEnvironmentVariablesMessage) _then) = _$SetEnvironmentVariablesMessageCopyWithImpl;
@useResult
$Res call({
 IMap<String, String?> environmentVariables
});




}
/// @nodoc
class _$SetEnvironmentVariablesMessageCopyWithImpl<$Res>
    implements $SetEnvironmentVariablesMessageCopyWith<$Res> {
  _$SetEnvironmentVariablesMessageCopyWithImpl(this._self, this._then);

  final SetEnvironmentVariablesMessage _self;
  final $Res Function(SetEnvironmentVariablesMessage) _then;

/// Create a copy of SetEnvironmentVariablesMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? environmentVariables = null,}) {
  return _then(_self.copyWith(
environmentVariables: null == environmentVariables ? _self.environmentVariables : environmentVariables // ignore: cast_nullable_to_non_nullable
as IMap<String, String?>,
  ));
}

}


/// Adds pattern-matching-related methods to [SetEnvironmentVariablesMessage].
extension SetEnvironmentVariablesMessagePatterns on SetEnvironmentVariablesMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SetEnvironmentVariablesMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SetEnvironmentVariablesMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SetEnvironmentVariablesMessage value)  $default,){
final _that = this;
switch (_that) {
case _SetEnvironmentVariablesMessage():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SetEnvironmentVariablesMessage value)?  $default,){
final _that = this;
switch (_that) {
case _SetEnvironmentVariablesMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IMap<String, String?> environmentVariables)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SetEnvironmentVariablesMessage() when $default != null:
return $default(_that.environmentVariables);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IMap<String, String?> environmentVariables)  $default,) {final _that = this;
switch (_that) {
case _SetEnvironmentVariablesMessage():
return $default(_that.environmentVariables);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IMap<String, String?> environmentVariables)?  $default,) {final _that = this;
switch (_that) {
case _SetEnvironmentVariablesMessage() when $default != null:
return $default(_that.environmentVariables);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SetEnvironmentVariablesMessage implements SetEnvironmentVariablesMessage {
   _SetEnvironmentVariablesMessage({required this.environmentVariables});
  factory _SetEnvironmentVariablesMessage.fromJson(Map<String, dynamic> json) => _$SetEnvironmentVariablesMessageFromJson(json);

/// A nullable value means that the variable should be unset.
@override final  IMap<String, String?> environmentVariables;

/// Create a copy of SetEnvironmentVariablesMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetEnvironmentVariablesMessageCopyWith<_SetEnvironmentVariablesMessage> get copyWith => __$SetEnvironmentVariablesMessageCopyWithImpl<_SetEnvironmentVariablesMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SetEnvironmentVariablesMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetEnvironmentVariablesMessage&&(identical(other.environmentVariables, environmentVariables) || other.environmentVariables == environmentVariables));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,environmentVariables);

@override
String toString() {
  return 'SetEnvironmentVariablesMessage(environmentVariables: $environmentVariables)';
}


}

/// @nodoc
abstract mixin class _$SetEnvironmentVariablesMessageCopyWith<$Res> implements $SetEnvironmentVariablesMessageCopyWith<$Res> {
  factory _$SetEnvironmentVariablesMessageCopyWith(_SetEnvironmentVariablesMessage value, $Res Function(_SetEnvironmentVariablesMessage) _then) = __$SetEnvironmentVariablesMessageCopyWithImpl;
@override @useResult
$Res call({
 IMap<String, String?> environmentVariables
});




}
/// @nodoc
class __$SetEnvironmentVariablesMessageCopyWithImpl<$Res>
    implements _$SetEnvironmentVariablesMessageCopyWith<$Res> {
  __$SetEnvironmentVariablesMessageCopyWithImpl(this._self, this._then);

  final _SetEnvironmentVariablesMessage _self;
  final $Res Function(_SetEnvironmentVariablesMessage) _then;

/// Create a copy of SetEnvironmentVariablesMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? environmentVariables = null,}) {
  return _then(_SetEnvironmentVariablesMessage(
environmentVariables: null == environmentVariables ? _self.environmentVariables : environmentVariables // ignore: cast_nullable_to_non_nullable
as IMap<String, String?>,
  ));
}


}

// dart format on

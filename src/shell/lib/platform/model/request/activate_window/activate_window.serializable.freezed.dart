// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activate_window.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ActivateWindowMessage {

 SurfaceId get surfaceId; bool get activate;
/// Create a copy of ActivateWindowMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivateWindowMessageCopyWith<ActivateWindowMessage> get copyWith => _$ActivateWindowMessageCopyWithImpl<ActivateWindowMessage>(this as ActivateWindowMessage, _$identity);

  /// Serializes this ActivateWindowMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivateWindowMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.activate, activate) || other.activate == activate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId,activate);

@override
String toString() {
  return 'ActivateWindowMessage(surfaceId: $surfaceId, activate: $activate)';
}


}

/// @nodoc
abstract mixin class $ActivateWindowMessageCopyWith<$Res>  {
  factory $ActivateWindowMessageCopyWith(ActivateWindowMessage value, $Res Function(ActivateWindowMessage) _then) = _$ActivateWindowMessageCopyWithImpl;
@useResult
$Res call({
 SurfaceId surfaceId, bool activate
});




}
/// @nodoc
class _$ActivateWindowMessageCopyWithImpl<$Res>
    implements $ActivateWindowMessageCopyWith<$Res> {
  _$ActivateWindowMessageCopyWithImpl(this._self, this._then);

  final ActivateWindowMessage _self;
  final $Res Function(ActivateWindowMessage) _then;

/// Create a copy of ActivateWindowMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? surfaceId = null,Object? activate = null,}) {
  return _then(_self.copyWith(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,activate: null == activate ? _self.activate : activate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivateWindowMessage].
extension ActivateWindowMessagePatterns on ActivateWindowMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivateWindowMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivateWindowMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivateWindowMessage value)  $default,){
final _that = this;
switch (_that) {
case _ActivateWindowMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivateWindowMessage value)?  $default,){
final _that = this;
switch (_that) {
case _ActivateWindowMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SurfaceId surfaceId,  bool activate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivateWindowMessage() when $default != null:
return $default(_that.surfaceId,_that.activate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SurfaceId surfaceId,  bool activate)  $default,) {final _that = this;
switch (_that) {
case _ActivateWindowMessage():
return $default(_that.surfaceId,_that.activate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SurfaceId surfaceId,  bool activate)?  $default,) {final _that = this;
switch (_that) {
case _ActivateWindowMessage() when $default != null:
return $default(_that.surfaceId,_that.activate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActivateWindowMessage implements ActivateWindowMessage {
   _ActivateWindowMessage({required this.surfaceId, required this.activate});
  factory _ActivateWindowMessage.fromJson(Map<String, dynamic> json) => _$ActivateWindowMessageFromJson(json);

@override final  SurfaceId surfaceId;
@override final  bool activate;

/// Create a copy of ActivateWindowMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivateWindowMessageCopyWith<_ActivateWindowMessage> get copyWith => __$ActivateWindowMessageCopyWithImpl<_ActivateWindowMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActivateWindowMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivateWindowMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.activate, activate) || other.activate == activate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId,activate);

@override
String toString() {
  return 'ActivateWindowMessage(surfaceId: $surfaceId, activate: $activate)';
}


}

/// @nodoc
abstract mixin class _$ActivateWindowMessageCopyWith<$Res> implements $ActivateWindowMessageCopyWith<$Res> {
  factory _$ActivateWindowMessageCopyWith(_ActivateWindowMessage value, $Res Function(_ActivateWindowMessage) _then) = __$ActivateWindowMessageCopyWithImpl;
@override @useResult
$Res call({
 SurfaceId surfaceId, bool activate
});




}
/// @nodoc
class __$ActivateWindowMessageCopyWithImpl<$Res>
    implements _$ActivateWindowMessageCopyWith<$Res> {
  __$ActivateWindowMessageCopyWithImpl(this._self, this._then);

  final _ActivateWindowMessage _self;
  final $Res Function(_ActivateWindowMessage) _then;

/// Create a copy of ActivateWindowMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surfaceId = null,Object? activate = null,}) {
  return _then(_ActivateWindowMessage(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,activate: null == activate ? _self.activate : activate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

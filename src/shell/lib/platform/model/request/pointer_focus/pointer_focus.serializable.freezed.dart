// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pointer_focus.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PointerFocusMessage {

 PointerFocus? get focus;
/// Create a copy of PointerFocusMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PointerFocusMessageCopyWith<PointerFocusMessage> get copyWith => _$PointerFocusMessageCopyWithImpl<PointerFocusMessage>(this as PointerFocusMessage, _$identity);

  /// Serializes this PointerFocusMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PointerFocusMessage&&(identical(other.focus, focus) || other.focus == focus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,focus);

@override
String toString() {
  return 'PointerFocusMessage(focus: $focus)';
}


}

/// @nodoc
abstract mixin class $PointerFocusMessageCopyWith<$Res>  {
  factory $PointerFocusMessageCopyWith(PointerFocusMessage value, $Res Function(PointerFocusMessage) _then) = _$PointerFocusMessageCopyWithImpl;
@useResult
$Res call({
 PointerFocus? focus
});


$PointerFocusCopyWith<$Res>? get focus;

}
/// @nodoc
class _$PointerFocusMessageCopyWithImpl<$Res>
    implements $PointerFocusMessageCopyWith<$Res> {
  _$PointerFocusMessageCopyWithImpl(this._self, this._then);

  final PointerFocusMessage _self;
  final $Res Function(PointerFocusMessage) _then;

/// Create a copy of PointerFocusMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? focus = freezed,}) {
  return _then(_self.copyWith(
focus: freezed == focus ? _self.focus : focus // ignore: cast_nullable_to_non_nullable
as PointerFocus?,
  ));
}
/// Create a copy of PointerFocusMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PointerFocusCopyWith<$Res>? get focus {
    if (_self.focus == null) {
    return null;
  }

  return $PointerFocusCopyWith<$Res>(_self.focus!, (value) {
    return _then(_self.copyWith(focus: value));
  });
}
}


/// Adds pattern-matching-related methods to [PointerFocusMessage].
extension PointerFocusMessagePatterns on PointerFocusMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PointerFocusMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PointerFocusMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PointerFocusMessage value)  $default,){
final _that = this;
switch (_that) {
case _PointerFocusMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PointerFocusMessage value)?  $default,){
final _that = this;
switch (_that) {
case _PointerFocusMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PointerFocus? focus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PointerFocusMessage() when $default != null:
return $default(_that.focus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PointerFocus? focus)  $default,) {final _that = this;
switch (_that) {
case _PointerFocusMessage():
return $default(_that.focus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PointerFocus? focus)?  $default,) {final _that = this;
switch (_that) {
case _PointerFocusMessage() when $default != null:
return $default(_that.focus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PointerFocusMessage implements PointerFocusMessage {
   _PointerFocusMessage({required this.focus});
  factory _PointerFocusMessage.fromJson(Map<String, dynamic> json) => _$PointerFocusMessageFromJson(json);

@override final  PointerFocus? focus;

/// Create a copy of PointerFocusMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PointerFocusMessageCopyWith<_PointerFocusMessage> get copyWith => __$PointerFocusMessageCopyWithImpl<_PointerFocusMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PointerFocusMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PointerFocusMessage&&(identical(other.focus, focus) || other.focus == focus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,focus);

@override
String toString() {
  return 'PointerFocusMessage(focus: $focus)';
}


}

/// @nodoc
abstract mixin class _$PointerFocusMessageCopyWith<$Res> implements $PointerFocusMessageCopyWith<$Res> {
  factory _$PointerFocusMessageCopyWith(_PointerFocusMessage value, $Res Function(_PointerFocusMessage) _then) = __$PointerFocusMessageCopyWithImpl;
@override @useResult
$Res call({
 PointerFocus? focus
});


@override $PointerFocusCopyWith<$Res>? get focus;

}
/// @nodoc
class __$PointerFocusMessageCopyWithImpl<$Res>
    implements _$PointerFocusMessageCopyWith<$Res> {
  __$PointerFocusMessageCopyWithImpl(this._self, this._then);

  final _PointerFocusMessage _self;
  final $Res Function(_PointerFocusMessage) _then;

/// Create a copy of PointerFocusMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? focus = freezed,}) {
  return _then(_PointerFocusMessage(
focus: freezed == focus ? _self.focus : focus // ignore: cast_nullable_to_non_nullable
as PointerFocus?,
  ));
}

/// Create a copy of PointerFocusMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PointerFocusCopyWith<$Res>? get focus {
    if (_self.focus == null) {
    return null;
  }

  return $PointerFocusCopyWith<$Res>(_self.focus!, (value) {
    return _then(_self.copyWith(focus: value));
  });
}
}

// dart format on

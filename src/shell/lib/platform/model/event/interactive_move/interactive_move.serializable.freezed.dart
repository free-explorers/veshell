// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'interactive_move.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InteractiveMoveMessage {

 MetaWindowId get metaWindowId;
/// Create a copy of InteractiveMoveMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InteractiveMoveMessageCopyWith<InteractiveMoveMessage> get copyWith => _$InteractiveMoveMessageCopyWithImpl<InteractiveMoveMessage>(this as InteractiveMoveMessage, _$identity);

  /// Serializes this InteractiveMoveMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InteractiveMoveMessage&&(identical(other.metaWindowId, metaWindowId) || other.metaWindowId == metaWindowId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,metaWindowId);

@override
String toString() {
  return 'InteractiveMoveMessage(metaWindowId: $metaWindowId)';
}


}

/// @nodoc
abstract mixin class $InteractiveMoveMessageCopyWith<$Res>  {
  factory $InteractiveMoveMessageCopyWith(InteractiveMoveMessage value, $Res Function(InteractiveMoveMessage) _then) = _$InteractiveMoveMessageCopyWithImpl;
@useResult
$Res call({
 MetaWindowId metaWindowId
});




}
/// @nodoc
class _$InteractiveMoveMessageCopyWithImpl<$Res>
    implements $InteractiveMoveMessageCopyWith<$Res> {
  _$InteractiveMoveMessageCopyWithImpl(this._self, this._then);

  final InteractiveMoveMessage _self;
  final $Res Function(InteractiveMoveMessage) _then;

/// Create a copy of InteractiveMoveMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? metaWindowId = null,}) {
  return _then(_self.copyWith(
metaWindowId: null == metaWindowId ? _self.metaWindowId : metaWindowId // ignore: cast_nullable_to_non_nullable
as MetaWindowId,
  ));
}

}


/// Adds pattern-matching-related methods to [InteractiveMoveMessage].
extension InteractiveMoveMessagePatterns on InteractiveMoveMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InteractiveMoveMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InteractiveMoveMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InteractiveMoveMessage value)  $default,){
final _that = this;
switch (_that) {
case _InteractiveMoveMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InteractiveMoveMessage value)?  $default,){
final _that = this;
switch (_that) {
case _InteractiveMoveMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MetaWindowId metaWindowId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InteractiveMoveMessage() when $default != null:
return $default(_that.metaWindowId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MetaWindowId metaWindowId)  $default,) {final _that = this;
switch (_that) {
case _InteractiveMoveMessage():
return $default(_that.metaWindowId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MetaWindowId metaWindowId)?  $default,) {final _that = this;
switch (_that) {
case _InteractiveMoveMessage() when $default != null:
return $default(_that.metaWindowId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InteractiveMoveMessage implements InteractiveMoveMessage {
   _InteractiveMoveMessage({required this.metaWindowId});
  factory _InteractiveMoveMessage.fromJson(Map<String, dynamic> json) => _$InteractiveMoveMessageFromJson(json);

@override final  MetaWindowId metaWindowId;

/// Create a copy of InteractiveMoveMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InteractiveMoveMessageCopyWith<_InteractiveMoveMessage> get copyWith => __$InteractiveMoveMessageCopyWithImpl<_InteractiveMoveMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InteractiveMoveMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InteractiveMoveMessage&&(identical(other.metaWindowId, metaWindowId) || other.metaWindowId == metaWindowId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,metaWindowId);

@override
String toString() {
  return 'InteractiveMoveMessage(metaWindowId: $metaWindowId)';
}


}

/// @nodoc
abstract mixin class _$InteractiveMoveMessageCopyWith<$Res> implements $InteractiveMoveMessageCopyWith<$Res> {
  factory _$InteractiveMoveMessageCopyWith(_InteractiveMoveMessage value, $Res Function(_InteractiveMoveMessage) _then) = __$InteractiveMoveMessageCopyWithImpl;
@override @useResult
$Res call({
 MetaWindowId metaWindowId
});




}
/// @nodoc
class __$InteractiveMoveMessageCopyWithImpl<$Res>
    implements _$InteractiveMoveMessageCopyWith<$Res> {
  __$InteractiveMoveMessageCopyWithImpl(this._self, this._then);

  final _InteractiveMoveMessage _self;
  final $Res Function(_InteractiveMoveMessage) _then;

/// Create a copy of InteractiveMoveMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? metaWindowId = null,}) {
  return _then(_InteractiveMoveMessage(
metaWindowId: null == metaWindowId ? _self.metaWindowId : metaWindowId // ignore: cast_nullable_to_non_nullable
as MetaWindowId,
  ));
}


}

// dart format on

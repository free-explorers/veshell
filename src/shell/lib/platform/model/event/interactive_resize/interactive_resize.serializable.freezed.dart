// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'interactive_resize.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InteractiveResizeMessage {

 MetaWindowId get metaWindowId;@ResizeEdgeConverter() ResizeEdge get edge;
/// Create a copy of InteractiveResizeMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InteractiveResizeMessageCopyWith<InteractiveResizeMessage> get copyWith => _$InteractiveResizeMessageCopyWithImpl<InteractiveResizeMessage>(this as InteractiveResizeMessage, _$identity);

  /// Serializes this InteractiveResizeMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InteractiveResizeMessage&&(identical(other.metaWindowId, metaWindowId) || other.metaWindowId == metaWindowId)&&(identical(other.edge, edge) || other.edge == edge));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,metaWindowId,edge);

@override
String toString() {
  return 'InteractiveResizeMessage(metaWindowId: $metaWindowId, edge: $edge)';
}


}

/// @nodoc
abstract mixin class $InteractiveResizeMessageCopyWith<$Res>  {
  factory $InteractiveResizeMessageCopyWith(InteractiveResizeMessage value, $Res Function(InteractiveResizeMessage) _then) = _$InteractiveResizeMessageCopyWithImpl;
@useResult
$Res call({
 MetaWindowId metaWindowId,@ResizeEdgeConverter() ResizeEdge edge
});




}
/// @nodoc
class _$InteractiveResizeMessageCopyWithImpl<$Res>
    implements $InteractiveResizeMessageCopyWith<$Res> {
  _$InteractiveResizeMessageCopyWithImpl(this._self, this._then);

  final InteractiveResizeMessage _self;
  final $Res Function(InteractiveResizeMessage) _then;

/// Create a copy of InteractiveResizeMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? metaWindowId = null,Object? edge = null,}) {
  return _then(_self.copyWith(
metaWindowId: null == metaWindowId ? _self.metaWindowId : metaWindowId // ignore: cast_nullable_to_non_nullable
as MetaWindowId,edge: null == edge ? _self.edge : edge // ignore: cast_nullable_to_non_nullable
as ResizeEdge,
  ));
}

}


/// Adds pattern-matching-related methods to [InteractiveResizeMessage].
extension InteractiveResizeMessagePatterns on InteractiveResizeMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InteractiveResizeMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InteractiveResizeMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InteractiveResizeMessage value)  $default,){
final _that = this;
switch (_that) {
case _InteractiveResizeMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InteractiveResizeMessage value)?  $default,){
final _that = this;
switch (_that) {
case _InteractiveResizeMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MetaWindowId metaWindowId, @ResizeEdgeConverter()  ResizeEdge edge)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InteractiveResizeMessage() when $default != null:
return $default(_that.metaWindowId,_that.edge);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MetaWindowId metaWindowId, @ResizeEdgeConverter()  ResizeEdge edge)  $default,) {final _that = this;
switch (_that) {
case _InteractiveResizeMessage():
return $default(_that.metaWindowId,_that.edge);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MetaWindowId metaWindowId, @ResizeEdgeConverter()  ResizeEdge edge)?  $default,) {final _that = this;
switch (_that) {
case _InteractiveResizeMessage() when $default != null:
return $default(_that.metaWindowId,_that.edge);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InteractiveResizeMessage implements InteractiveResizeMessage {
   _InteractiveResizeMessage({required this.metaWindowId, @ResizeEdgeConverter() required this.edge});
  factory _InteractiveResizeMessage.fromJson(Map<String, dynamic> json) => _$InteractiveResizeMessageFromJson(json);

@override final  MetaWindowId metaWindowId;
@override@ResizeEdgeConverter() final  ResizeEdge edge;

/// Create a copy of InteractiveResizeMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InteractiveResizeMessageCopyWith<_InteractiveResizeMessage> get copyWith => __$InteractiveResizeMessageCopyWithImpl<_InteractiveResizeMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InteractiveResizeMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InteractiveResizeMessage&&(identical(other.metaWindowId, metaWindowId) || other.metaWindowId == metaWindowId)&&(identical(other.edge, edge) || other.edge == edge));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,metaWindowId,edge);

@override
String toString() {
  return 'InteractiveResizeMessage(metaWindowId: $metaWindowId, edge: $edge)';
}


}

/// @nodoc
abstract mixin class _$InteractiveResizeMessageCopyWith<$Res> implements $InteractiveResizeMessageCopyWith<$Res> {
  factory _$InteractiveResizeMessageCopyWith(_InteractiveResizeMessage value, $Res Function(_InteractiveResizeMessage) _then) = __$InteractiveResizeMessageCopyWithImpl;
@override @useResult
$Res call({
 MetaWindowId metaWindowId,@ResizeEdgeConverter() ResizeEdge edge
});




}
/// @nodoc
class __$InteractiveResizeMessageCopyWithImpl<$Res>
    implements _$InteractiveResizeMessageCopyWith<$Res> {
  __$InteractiveResizeMessageCopyWithImpl(this._self, this._then);

  final _InteractiveResizeMessage _self;
  final $Res Function(_InteractiveResizeMessage) _then;

/// Create a copy of InteractiveResizeMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? metaWindowId = null,Object? edge = null,}) {
  return _then(_InteractiveResizeMessage(
metaWindowId: null == metaWindowId ? _self.metaWindowId : metaWindowId // ignore: cast_nullable_to_non_nullable
as MetaWindowId,edge: null == edge ? _self.edge : edge // ignore: cast_nullable_to_non_nullable
as ResizeEdge,
  ));
}


}

// dart format on

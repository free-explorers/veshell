// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meta_window_removed.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MetaWindowRemovedMessage {

 String get id;
/// Create a copy of MetaWindowRemovedMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaWindowRemovedMessageCopyWith<MetaWindowRemovedMessage> get copyWith => _$MetaWindowRemovedMessageCopyWithImpl<MetaWindowRemovedMessage>(this as MetaWindowRemovedMessage, _$identity);

  /// Serializes this MetaWindowRemovedMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaWindowRemovedMessage&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'MetaWindowRemovedMessage(id: $id)';
}


}

/// @nodoc
abstract mixin class $MetaWindowRemovedMessageCopyWith<$Res>  {
  factory $MetaWindowRemovedMessageCopyWith(MetaWindowRemovedMessage value, $Res Function(MetaWindowRemovedMessage) _then) = _$MetaWindowRemovedMessageCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$MetaWindowRemovedMessageCopyWithImpl<$Res>
    implements $MetaWindowRemovedMessageCopyWith<$Res> {
  _$MetaWindowRemovedMessageCopyWithImpl(this._self, this._then);

  final MetaWindowRemovedMessage _self;
  final $Res Function(MetaWindowRemovedMessage) _then;

/// Create a copy of MetaWindowRemovedMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MetaWindowRemovedMessage].
extension MetaWindowRemovedMessagePatterns on MetaWindowRemovedMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MetaWindowRemovedMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MetaWindowRemovedMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MetaWindowRemovedMessage value)  $default,){
final _that = this;
switch (_that) {
case _MetaWindowRemovedMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MetaWindowRemovedMessage value)?  $default,){
final _that = this;
switch (_that) {
case _MetaWindowRemovedMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MetaWindowRemovedMessage() when $default != null:
return $default(_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id)  $default,) {final _that = this;
switch (_that) {
case _MetaWindowRemovedMessage():
return $default(_that.id);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id)?  $default,) {final _that = this;
switch (_that) {
case _MetaWindowRemovedMessage() when $default != null:
return $default(_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MetaWindowRemovedMessage implements MetaWindowRemovedMessage {
   _MetaWindowRemovedMessage({required this.id});
  factory _MetaWindowRemovedMessage.fromJson(Map<String, dynamic> json) => _$MetaWindowRemovedMessageFromJson(json);

@override final  String id;

/// Create a copy of MetaWindowRemovedMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MetaWindowRemovedMessageCopyWith<_MetaWindowRemovedMessage> get copyWith => __$MetaWindowRemovedMessageCopyWithImpl<_MetaWindowRemovedMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaWindowRemovedMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MetaWindowRemovedMessage&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'MetaWindowRemovedMessage(id: $id)';
}


}

/// @nodoc
abstract mixin class _$MetaWindowRemovedMessageCopyWith<$Res> implements $MetaWindowRemovedMessageCopyWith<$Res> {
  factory _$MetaWindowRemovedMessageCopyWith(_MetaWindowRemovedMessage value, $Res Function(_MetaWindowRemovedMessage) _then) = __$MetaWindowRemovedMessageCopyWithImpl;
@override @useResult
$Res call({
 String id
});




}
/// @nodoc
class __$MetaWindowRemovedMessageCopyWithImpl<$Res>
    implements _$MetaWindowRemovedMessageCopyWith<$Res> {
  __$MetaWindowRemovedMessageCopyWithImpl(this._self, this._then);

  final _MetaWindowRemovedMessage _self;
  final $Res Function(_MetaWindowRemovedMessage) _then;

/// Create a copy of MetaWindowRemovedMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(_MetaWindowRemovedMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on

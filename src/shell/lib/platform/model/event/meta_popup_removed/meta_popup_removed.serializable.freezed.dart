// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meta_popup_removed.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MetaPopupRemovedMessage {

 String get id;
/// Create a copy of MetaPopupRemovedMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaPopupRemovedMessageCopyWith<MetaPopupRemovedMessage> get copyWith => _$MetaPopupRemovedMessageCopyWithImpl<MetaPopupRemovedMessage>(this as MetaPopupRemovedMessage, _$identity);

  /// Serializes this MetaPopupRemovedMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaPopupRemovedMessage&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'MetaPopupRemovedMessage(id: $id)';
}


}

/// @nodoc
abstract mixin class $MetaPopupRemovedMessageCopyWith<$Res>  {
  factory $MetaPopupRemovedMessageCopyWith(MetaPopupRemovedMessage value, $Res Function(MetaPopupRemovedMessage) _then) = _$MetaPopupRemovedMessageCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$MetaPopupRemovedMessageCopyWithImpl<$Res>
    implements $MetaPopupRemovedMessageCopyWith<$Res> {
  _$MetaPopupRemovedMessageCopyWithImpl(this._self, this._then);

  final MetaPopupRemovedMessage _self;
  final $Res Function(MetaPopupRemovedMessage) _then;

/// Create a copy of MetaPopupRemovedMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MetaPopupRemovedMessage].
extension MetaPopupRemovedMessagePatterns on MetaPopupRemovedMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MetaPopupRemovedMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MetaPopupRemovedMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MetaPopupRemovedMessage value)  $default,){
final _that = this;
switch (_that) {
case _MetaPopupRemovedMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MetaPopupRemovedMessage value)?  $default,){
final _that = this;
switch (_that) {
case _MetaPopupRemovedMessage() when $default != null:
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
case _MetaPopupRemovedMessage() when $default != null:
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
case _MetaPopupRemovedMessage():
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
case _MetaPopupRemovedMessage() when $default != null:
return $default(_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MetaPopupRemovedMessage implements MetaPopupRemovedMessage {
   _MetaPopupRemovedMessage({required this.id});
  factory _MetaPopupRemovedMessage.fromJson(Map<String, dynamic> json) => _$MetaPopupRemovedMessageFromJson(json);

@override final  String id;

/// Create a copy of MetaPopupRemovedMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MetaPopupRemovedMessageCopyWith<_MetaPopupRemovedMessage> get copyWith => __$MetaPopupRemovedMessageCopyWithImpl<_MetaPopupRemovedMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaPopupRemovedMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MetaPopupRemovedMessage&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'MetaPopupRemovedMessage(id: $id)';
}


}

/// @nodoc
abstract mixin class _$MetaPopupRemovedMessageCopyWith<$Res> implements $MetaPopupRemovedMessageCopyWith<$Res> {
  factory _$MetaPopupRemovedMessageCopyWith(_MetaPopupRemovedMessage value, $Res Function(_MetaPopupRemovedMessage) _then) = __$MetaPopupRemovedMessageCopyWithImpl;
@override @useResult
$Res call({
 String id
});




}
/// @nodoc
class __$MetaPopupRemovedMessageCopyWithImpl<$Res>
    implements _$MetaPopupRemovedMessageCopyWith<$Res> {
  __$MetaPopupRemovedMessageCopyWithImpl(this._self, this._then);

  final _MetaPopupRemovedMessage _self;
  final $Res Function(_MetaPopupRemovedMessage) _then;

/// Create a copy of MetaPopupRemovedMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(_MetaPopupRemovedMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on

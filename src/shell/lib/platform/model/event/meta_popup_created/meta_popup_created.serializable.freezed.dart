// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meta_popup_created.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MetaPopupCreatedMessage {

 MetaPopupId get id; MetaWindowId get parent; SurfaceId get surfaceId; double get scaleRatio;@OffsetConverter() Offset get position; String? get currentOutput;
/// Create a copy of MetaPopupCreatedMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaPopupCreatedMessageCopyWith<MetaPopupCreatedMessage> get copyWith => _$MetaPopupCreatedMessageCopyWithImpl<MetaPopupCreatedMessage>(this as MetaPopupCreatedMessage, _$identity);

  /// Serializes this MetaPopupCreatedMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaPopupCreatedMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.scaleRatio, scaleRatio) || other.scaleRatio == scaleRatio)&&(identical(other.position, position) || other.position == position)&&(identical(other.currentOutput, currentOutput) || other.currentOutput == currentOutput));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parent,surfaceId,scaleRatio,position,currentOutput);

@override
String toString() {
  return 'MetaPopupCreatedMessage(id: $id, parent: $parent, surfaceId: $surfaceId, scaleRatio: $scaleRatio, position: $position, currentOutput: $currentOutput)';
}


}

/// @nodoc
abstract mixin class $MetaPopupCreatedMessageCopyWith<$Res>  {
  factory $MetaPopupCreatedMessageCopyWith(MetaPopupCreatedMessage value, $Res Function(MetaPopupCreatedMessage) _then) = _$MetaPopupCreatedMessageCopyWithImpl;
@useResult
$Res call({
 MetaPopupId id, MetaWindowId parent, SurfaceId surfaceId, double scaleRatio,@OffsetConverter() Offset position, String? currentOutput
});




}
/// @nodoc
class _$MetaPopupCreatedMessageCopyWithImpl<$Res>
    implements $MetaPopupCreatedMessageCopyWith<$Res> {
  _$MetaPopupCreatedMessageCopyWithImpl(this._self, this._then);

  final MetaPopupCreatedMessage _self;
  final $Res Function(MetaPopupCreatedMessage) _then;

/// Create a copy of MetaPopupCreatedMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? parent = null,Object? surfaceId = null,Object? scaleRatio = null,Object? position = null,Object? currentOutput = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as MetaPopupId,parent: null == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as MetaWindowId,surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,scaleRatio: null == scaleRatio ? _self.scaleRatio : scaleRatio // ignore: cast_nullable_to_non_nullable
as double,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Offset,currentOutput: freezed == currentOutput ? _self.currentOutput : currentOutput // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MetaPopupCreatedMessage].
extension MetaPopupCreatedMessagePatterns on MetaPopupCreatedMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MetaPopupCreatedMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MetaPopupCreatedMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MetaPopupCreatedMessage value)  $default,){
final _that = this;
switch (_that) {
case _MetaPopupCreatedMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MetaPopupCreatedMessage value)?  $default,){
final _that = this;
switch (_that) {
case _MetaPopupCreatedMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MetaPopupId id,  MetaWindowId parent,  SurfaceId surfaceId,  double scaleRatio, @OffsetConverter()  Offset position,  String? currentOutput)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MetaPopupCreatedMessage() when $default != null:
return $default(_that.id,_that.parent,_that.surfaceId,_that.scaleRatio,_that.position,_that.currentOutput);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MetaPopupId id,  MetaWindowId parent,  SurfaceId surfaceId,  double scaleRatio, @OffsetConverter()  Offset position,  String? currentOutput)  $default,) {final _that = this;
switch (_that) {
case _MetaPopupCreatedMessage():
return $default(_that.id,_that.parent,_that.surfaceId,_that.scaleRatio,_that.position,_that.currentOutput);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MetaPopupId id,  MetaWindowId parent,  SurfaceId surfaceId,  double scaleRatio, @OffsetConverter()  Offset position,  String? currentOutput)?  $default,) {final _that = this;
switch (_that) {
case _MetaPopupCreatedMessage() when $default != null:
return $default(_that.id,_that.parent,_that.surfaceId,_that.scaleRatio,_that.position,_that.currentOutput);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MetaPopupCreatedMessage implements MetaPopupCreatedMessage {
   _MetaPopupCreatedMessage({required this.id, required this.parent, required this.surfaceId, required this.scaleRatio, @OffsetConverter() required this.position, this.currentOutput});
  factory _MetaPopupCreatedMessage.fromJson(Map<String, dynamic> json) => _$MetaPopupCreatedMessageFromJson(json);

@override final  MetaPopupId id;
@override final  MetaWindowId parent;
@override final  SurfaceId surfaceId;
@override final  double scaleRatio;
@override@OffsetConverter() final  Offset position;
@override final  String? currentOutput;

/// Create a copy of MetaPopupCreatedMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MetaPopupCreatedMessageCopyWith<_MetaPopupCreatedMessage> get copyWith => __$MetaPopupCreatedMessageCopyWithImpl<_MetaPopupCreatedMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaPopupCreatedMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MetaPopupCreatedMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.scaleRatio, scaleRatio) || other.scaleRatio == scaleRatio)&&(identical(other.position, position) || other.position == position)&&(identical(other.currentOutput, currentOutput) || other.currentOutput == currentOutput));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parent,surfaceId,scaleRatio,position,currentOutput);

@override
String toString() {
  return 'MetaPopupCreatedMessage(id: $id, parent: $parent, surfaceId: $surfaceId, scaleRatio: $scaleRatio, position: $position, currentOutput: $currentOutput)';
}


}

/// @nodoc
abstract mixin class _$MetaPopupCreatedMessageCopyWith<$Res> implements $MetaPopupCreatedMessageCopyWith<$Res> {
  factory _$MetaPopupCreatedMessageCopyWith(_MetaPopupCreatedMessage value, $Res Function(_MetaPopupCreatedMessage) _then) = __$MetaPopupCreatedMessageCopyWithImpl;
@override @useResult
$Res call({
 MetaPopupId id, MetaWindowId parent, SurfaceId surfaceId, double scaleRatio,@OffsetConverter() Offset position, String? currentOutput
});




}
/// @nodoc
class __$MetaPopupCreatedMessageCopyWithImpl<$Res>
    implements _$MetaPopupCreatedMessageCopyWith<$Res> {
  __$MetaPopupCreatedMessageCopyWithImpl(this._self, this._then);

  final _MetaPopupCreatedMessage _self;
  final $Res Function(_MetaPopupCreatedMessage) _then;

/// Create a copy of MetaPopupCreatedMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parent = null,Object? surfaceId = null,Object? scaleRatio = null,Object? position = null,Object? currentOutput = freezed,}) {
  return _then(_MetaPopupCreatedMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as MetaPopupId,parent: null == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as MetaWindowId,surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,scaleRatio: null == scaleRatio ? _self.scaleRatio : scaleRatio // ignore: cast_nullable_to_non_nullable
as double,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Offset,currentOutput: freezed == currentOutput ? _self.currentOutput : currentOutput // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

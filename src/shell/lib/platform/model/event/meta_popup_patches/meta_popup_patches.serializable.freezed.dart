// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meta_popup_patches.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
MetaPopupPatchMessage _$MetaPopupPatchMessageFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'UpdatePosition':
          return UpdatePosition.fromJson(
            json
          );
                case 'UpdateScaleRatio':
          return UpdateScaleRatio.fromJson(
            json
          );
                case 'UpdateGeometry':
          return UpdateGeometry.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'MetaPopupPatchMessage',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$MetaPopupPatchMessage {

 String get id;@OffsetConverter()@RectConverter() Object get value;
/// Create a copy of MetaPopupPatchMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaPopupPatchMessageCopyWith<MetaPopupPatchMessage> get copyWith => _$MetaPopupPatchMessageCopyWithImpl<MetaPopupPatchMessage>(this as MetaPopupPatchMessage, _$identity);

  /// Serializes this MetaPopupPatchMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaPopupPatchMessage&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.value, value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'MetaPopupPatchMessage(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $MetaPopupPatchMessageCopyWith<$Res>  {
  factory $MetaPopupPatchMessageCopyWith(MetaPopupPatchMessage value, $Res Function(MetaPopupPatchMessage) _then) = _$MetaPopupPatchMessageCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$MetaPopupPatchMessageCopyWithImpl<$Res>
    implements $MetaPopupPatchMessageCopyWith<$Res> {
  _$MetaPopupPatchMessageCopyWithImpl(this._self, this._then);

  final MetaPopupPatchMessage _self;
  final $Res Function(MetaPopupPatchMessage) _then;

/// Create a copy of MetaPopupPatchMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MetaPopupPatchMessage].
extension MetaPopupPatchMessagePatterns on MetaPopupPatchMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UpdatePosition value)?  updatePosition,TResult Function( UpdateScaleRatio value)?  updateScaleRatio,TResult Function( UpdateGeometry value)?  updateGeometry,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UpdatePosition() when updatePosition != null:
return updatePosition(_that);case UpdateScaleRatio() when updateScaleRatio != null:
return updateScaleRatio(_that);case UpdateGeometry() when updateGeometry != null:
return updateGeometry(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UpdatePosition value)  updatePosition,required TResult Function( UpdateScaleRatio value)  updateScaleRatio,required TResult Function( UpdateGeometry value)  updateGeometry,}){
final _that = this;
switch (_that) {
case UpdatePosition():
return updatePosition(_that);case UpdateScaleRatio():
return updateScaleRatio(_that);case UpdateGeometry():
return updateGeometry(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UpdatePosition value)?  updatePosition,TResult? Function( UpdateScaleRatio value)?  updateScaleRatio,TResult? Function( UpdateGeometry value)?  updateGeometry,}){
final _that = this;
switch (_that) {
case UpdatePosition() when updatePosition != null:
return updatePosition(_that);case UpdateScaleRatio() when updateScaleRatio != null:
return updateScaleRatio(_that);case UpdateGeometry() when updateGeometry != null:
return updateGeometry(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id, @OffsetConverter()  Offset value)?  updatePosition,TResult Function( String id,  double value)?  updateScaleRatio,TResult Function( String id, @RectConverter()  Rect value)?  updateGeometry,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UpdatePosition() when updatePosition != null:
return updatePosition(_that.id,_that.value);case UpdateScaleRatio() when updateScaleRatio != null:
return updateScaleRatio(_that.id,_that.value);case UpdateGeometry() when updateGeometry != null:
return updateGeometry(_that.id,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id, @OffsetConverter()  Offset value)  updatePosition,required TResult Function( String id,  double value)  updateScaleRatio,required TResult Function( String id, @RectConverter()  Rect value)  updateGeometry,}) {final _that = this;
switch (_that) {
case UpdatePosition():
return updatePosition(_that.id,_that.value);case UpdateScaleRatio():
return updateScaleRatio(_that.id,_that.value);case UpdateGeometry():
return updateGeometry(_that.id,_that.value);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id, @OffsetConverter()  Offset value)?  updatePosition,TResult? Function( String id,  double value)?  updateScaleRatio,TResult? Function( String id, @RectConverter()  Rect value)?  updateGeometry,}) {final _that = this;
switch (_that) {
case UpdatePosition() when updatePosition != null:
return updatePosition(_that.id,_that.value);case UpdateScaleRatio() when updateScaleRatio != null:
return updateScaleRatio(_that.id,_that.value);case UpdateGeometry() when updateGeometry != null:
return updateGeometry(_that.id,_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class UpdatePosition implements MetaPopupPatchMessage {
  const UpdatePosition({required this.id, @OffsetConverter() required this.value, final  String? $type}): $type = $type ?? 'UpdatePosition';
  factory UpdatePosition.fromJson(Map<String, dynamic> json) => _$UpdatePositionFromJson(json);

@override final  String id;
@override@OffsetConverter() final  Offset value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaPopupPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdatePositionCopyWith<UpdatePosition> get copyWith => _$UpdatePositionCopyWithImpl<UpdatePosition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdatePositionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdatePosition&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaPopupPatchMessage.updatePosition(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdatePositionCopyWith<$Res> implements $MetaPopupPatchMessageCopyWith<$Res> {
  factory $UpdatePositionCopyWith(UpdatePosition value, $Res Function(UpdatePosition) _then) = _$UpdatePositionCopyWithImpl;
@override @useResult
$Res call({
 String id,@OffsetConverter() Offset value
});




}
/// @nodoc
class _$UpdatePositionCopyWithImpl<$Res>
    implements $UpdatePositionCopyWith<$Res> {
  _$UpdatePositionCopyWithImpl(this._self, this._then);

  final UpdatePosition _self;
  final $Res Function(UpdatePosition) _then;

/// Create a copy of MetaPopupPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = null,}) {
  return _then(UpdatePosition(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as Offset,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateScaleRatio implements MetaPopupPatchMessage {
  const UpdateScaleRatio({required this.id, required this.value, final  String? $type}): $type = $type ?? 'UpdateScaleRatio';
  factory UpdateScaleRatio.fromJson(Map<String, dynamic> json) => _$UpdateScaleRatioFromJson(json);

@override final  String id;
@override final  double value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaPopupPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateScaleRatioCopyWith<UpdateScaleRatio> get copyWith => _$UpdateScaleRatioCopyWithImpl<UpdateScaleRatio>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateScaleRatioToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateScaleRatio&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaPopupPatchMessage.updateScaleRatio(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateScaleRatioCopyWith<$Res> implements $MetaPopupPatchMessageCopyWith<$Res> {
  factory $UpdateScaleRatioCopyWith(UpdateScaleRatio value, $Res Function(UpdateScaleRatio) _then) = _$UpdateScaleRatioCopyWithImpl;
@override @useResult
$Res call({
 String id, double value
});




}
/// @nodoc
class _$UpdateScaleRatioCopyWithImpl<$Res>
    implements $UpdateScaleRatioCopyWith<$Res> {
  _$UpdateScaleRatioCopyWithImpl(this._self, this._then);

  final UpdateScaleRatio _self;
  final $Res Function(UpdateScaleRatio) _then;

/// Create a copy of MetaPopupPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = null,}) {
  return _then(UpdateScaleRatio(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateGeometry implements MetaPopupPatchMessage {
  const UpdateGeometry({required this.id, @RectConverter() required this.value, final  String? $type}): $type = $type ?? 'UpdateGeometry';
  factory UpdateGeometry.fromJson(Map<String, dynamic> json) => _$UpdateGeometryFromJson(json);

@override final  String id;
@override@RectConverter() final  Rect value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaPopupPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateGeometryCopyWith<UpdateGeometry> get copyWith => _$UpdateGeometryCopyWithImpl<UpdateGeometry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateGeometryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateGeometry&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaPopupPatchMessage.updateGeometry(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateGeometryCopyWith<$Res> implements $MetaPopupPatchMessageCopyWith<$Res> {
  factory $UpdateGeometryCopyWith(UpdateGeometry value, $Res Function(UpdateGeometry) _then) = _$UpdateGeometryCopyWithImpl;
@override @useResult
$Res call({
 String id,@RectConverter() Rect value
});




}
/// @nodoc
class _$UpdateGeometryCopyWithImpl<$Res>
    implements $UpdateGeometryCopyWith<$Res> {
  _$UpdateGeometryCopyWithImpl(this._self, this._then);

  final UpdateGeometry _self;
  final $Res Function(UpdateGeometry) _then;

/// Create a copy of MetaPopupPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = null,}) {
  return _then(UpdateGeometry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as Rect,
  ));
}


}

// dart format on

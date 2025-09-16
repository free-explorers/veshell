// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'window_id.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
WindowId _$WindowIdFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'dialog':
          return DialogWindowId.fromJson(
            json
          );
                case 'persistent':
          return PersistentWindowId.fromJson(
            json
          );
                case 'ephemeral':
          return EphemeralWindowId.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'WindowId',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$WindowId {

 String get uuid;
/// Create a copy of WindowId
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WindowIdCopyWith<WindowId> get copyWith => _$WindowIdCopyWithImpl<WindowId>(this as WindowId, _$identity);

  /// Serializes this WindowId to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WindowId&&(identical(other.uuid, uuid) || other.uuid == uuid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid);

@override
String toString() {
  return 'WindowId(uuid: $uuid)';
}


}

/// @nodoc
abstract mixin class $WindowIdCopyWith<$Res>  {
  factory $WindowIdCopyWith(WindowId value, $Res Function(WindowId) _then) = _$WindowIdCopyWithImpl;
@useResult
$Res call({
 String uuid
});




}
/// @nodoc
class _$WindowIdCopyWithImpl<$Res>
    implements $WindowIdCopyWith<$Res> {
  _$WindowIdCopyWithImpl(this._self, this._then);

  final WindowId _self;
  final $Res Function(WindowId) _then;

/// Create a copy of WindowId
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uuid = null,}) {
  return _then(_self.copyWith(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WindowId].
extension WindowIdPatterns on WindowId {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DialogWindowId value)?  dialog,TResult Function( PersistentWindowId value)?  persistent,TResult Function( EphemeralWindowId value)?  ephemeral,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DialogWindowId() when dialog != null:
return dialog(_that);case PersistentWindowId() when persistent != null:
return persistent(_that);case EphemeralWindowId() when ephemeral != null:
return ephemeral(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DialogWindowId value)  dialog,required TResult Function( PersistentWindowId value)  persistent,required TResult Function( EphemeralWindowId value)  ephemeral,}){
final _that = this;
switch (_that) {
case DialogWindowId():
return dialog(_that);case PersistentWindowId():
return persistent(_that);case EphemeralWindowId():
return ephemeral(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DialogWindowId value)?  dialog,TResult? Function( PersistentWindowId value)?  persistent,TResult? Function( EphemeralWindowId value)?  ephemeral,}){
final _that = this;
switch (_that) {
case DialogWindowId() when dialog != null:
return dialog(_that);case PersistentWindowId() when persistent != null:
return persistent(_that);case EphemeralWindowId() when ephemeral != null:
return ephemeral(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String uuid)?  dialog,TResult Function( String uuid)?  persistent,TResult Function( String uuid)?  ephemeral,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DialogWindowId() when dialog != null:
return dialog(_that.uuid);case PersistentWindowId() when persistent != null:
return persistent(_that.uuid);case EphemeralWindowId() when ephemeral != null:
return ephemeral(_that.uuid);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String uuid)  dialog,required TResult Function( String uuid)  persistent,required TResult Function( String uuid)  ephemeral,}) {final _that = this;
switch (_that) {
case DialogWindowId():
return dialog(_that.uuid);case PersistentWindowId():
return persistent(_that.uuid);case EphemeralWindowId():
return ephemeral(_that.uuid);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String uuid)?  dialog,TResult? Function( String uuid)?  persistent,TResult? Function( String uuid)?  ephemeral,}) {final _that = this;
switch (_that) {
case DialogWindowId() when dialog != null:
return dialog(_that.uuid);case PersistentWindowId() when persistent != null:
return persistent(_that.uuid);case EphemeralWindowId() when ephemeral != null:
return ephemeral(_that.uuid);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class DialogWindowId implements WindowId {
  const DialogWindowId(this.uuid, {final  String? $type}): $type = $type ?? 'dialog';
  factory DialogWindowId.fromJson(Map<String, dynamic> json) => _$DialogWindowIdFromJson(json);

@override final  String uuid;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of WindowId
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DialogWindowIdCopyWith<DialogWindowId> get copyWith => _$DialogWindowIdCopyWithImpl<DialogWindowId>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DialogWindowIdToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DialogWindowId&&(identical(other.uuid, uuid) || other.uuid == uuid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid);

@override
String toString() {
  return 'WindowId.dialog(uuid: $uuid)';
}


}

/// @nodoc
abstract mixin class $DialogWindowIdCopyWith<$Res> implements $WindowIdCopyWith<$Res> {
  factory $DialogWindowIdCopyWith(DialogWindowId value, $Res Function(DialogWindowId) _then) = _$DialogWindowIdCopyWithImpl;
@override @useResult
$Res call({
 String uuid
});




}
/// @nodoc
class _$DialogWindowIdCopyWithImpl<$Res>
    implements $DialogWindowIdCopyWith<$Res> {
  _$DialogWindowIdCopyWithImpl(this._self, this._then);

  final DialogWindowId _self;
  final $Res Function(DialogWindowId) _then;

/// Create a copy of WindowId
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,}) {
  return _then(DialogWindowId(
null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class PersistentWindowId implements WindowId {
  const PersistentWindowId(this.uuid, {final  String? $type}): $type = $type ?? 'persistent';
  factory PersistentWindowId.fromJson(Map<String, dynamic> json) => _$PersistentWindowIdFromJson(json);

@override final  String uuid;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of WindowId
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PersistentWindowIdCopyWith<PersistentWindowId> get copyWith => _$PersistentWindowIdCopyWithImpl<PersistentWindowId>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PersistentWindowIdToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PersistentWindowId&&(identical(other.uuid, uuid) || other.uuid == uuid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid);

@override
String toString() {
  return 'WindowId.persistent(uuid: $uuid)';
}


}

/// @nodoc
abstract mixin class $PersistentWindowIdCopyWith<$Res> implements $WindowIdCopyWith<$Res> {
  factory $PersistentWindowIdCopyWith(PersistentWindowId value, $Res Function(PersistentWindowId) _then) = _$PersistentWindowIdCopyWithImpl;
@override @useResult
$Res call({
 String uuid
});




}
/// @nodoc
class _$PersistentWindowIdCopyWithImpl<$Res>
    implements $PersistentWindowIdCopyWith<$Res> {
  _$PersistentWindowIdCopyWithImpl(this._self, this._then);

  final PersistentWindowId _self;
  final $Res Function(PersistentWindowId) _then;

/// Create a copy of WindowId
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,}) {
  return _then(PersistentWindowId(
null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class EphemeralWindowId implements WindowId {
  const EphemeralWindowId(this.uuid, {final  String? $type}): $type = $type ?? 'ephemeral';
  factory EphemeralWindowId.fromJson(Map<String, dynamic> json) => _$EphemeralWindowIdFromJson(json);

@override final  String uuid;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of WindowId
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EphemeralWindowIdCopyWith<EphemeralWindowId> get copyWith => _$EphemeralWindowIdCopyWithImpl<EphemeralWindowId>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EphemeralWindowIdToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EphemeralWindowId&&(identical(other.uuid, uuid) || other.uuid == uuid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid);

@override
String toString() {
  return 'WindowId.ephemeral(uuid: $uuid)';
}


}

/// @nodoc
abstract mixin class $EphemeralWindowIdCopyWith<$Res> implements $WindowIdCopyWith<$Res> {
  factory $EphemeralWindowIdCopyWith(EphemeralWindowId value, $Res Function(EphemeralWindowId) _then) = _$EphemeralWindowIdCopyWithImpl;
@override @useResult
$Res call({
 String uuid
});




}
/// @nodoc
class _$EphemeralWindowIdCopyWithImpl<$Res>
    implements $EphemeralWindowIdCopyWith<$Res> {
  _$EphemeralWindowIdCopyWithImpl(this._self, this._then);

  final EphemeralWindowId _self;
  final $Res Function(EphemeralWindowId) _then;

/// Create a copy of WindowId
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,}) {
  return _then(EphemeralWindowId(
null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on

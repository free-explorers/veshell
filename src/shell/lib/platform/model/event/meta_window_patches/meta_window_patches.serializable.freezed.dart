// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meta_window_patches.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
MetaWindowPatchMessage _$MetaWindowPatchMessageFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'UpdateAppId':
          return UpdateAppId.fromJson(
            json
          );
                case 'UpdateParent':
          return UpdateParent.fromJson(
            json
          );
                case 'UpdateTitle':
          return UpdateTitle.fromJson(
            json
          );
                case 'UpdatePid':
          return UpdatePid.fromJson(
            json
          );
                case 'UpdateWindowClass':
          return UpdateWindowClass.fromJson(
            json
          );
                case 'UpdateStartupId':
          return UpdateStartupId.fromJson(
            json
          );
                case 'UpdateDisplayMode':
          return UpdateDisplayMode.fromJson(
            json
          );
                case 'UpdateMapped':
          return UpdateMapped.fromJson(
            json
          );
                case 'UpdateGeometry':
          return UpdateGeometry.fromJson(
            json
          );
                case 'UpdateNeedDecoration':
          return UpdateNeedDecoration.fromJson(
            json
          );
                case 'UpdateGameModeActivated':
          return UpdateGameModeActivated.fromJson(
            json
          );
                case 'UpdateCurrentOutput':
          return UpdateCurrentOutput.fromJson(
            json
          );
                case 'UpdateScaleRatio':
          return UpdateScaleRatio.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'MetaWindowPatchMessage',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$MetaWindowPatchMessage {

 String get id;@RectConverter() Object? get value;
/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaWindowPatchMessageCopyWith<MetaWindowPatchMessage> get copyWith => _$MetaWindowPatchMessageCopyWithImpl<MetaWindowPatchMessage>(this as MetaWindowPatchMessage, _$identity);

  /// Serializes this MetaWindowPatchMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaWindowPatchMessage&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.value, value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'MetaWindowPatchMessage(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $MetaWindowPatchMessageCopyWith<$Res>  {
  factory $MetaWindowPatchMessageCopyWith(MetaWindowPatchMessage value, $Res Function(MetaWindowPatchMessage) _then) = _$MetaWindowPatchMessageCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$MetaWindowPatchMessageCopyWithImpl<$Res>
    implements $MetaWindowPatchMessageCopyWith<$Res> {
  _$MetaWindowPatchMessageCopyWithImpl(this._self, this._then);

  final MetaWindowPatchMessage _self;
  final $Res Function(MetaWindowPatchMessage) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MetaWindowPatchMessage].
extension MetaWindowPatchMessagePatterns on MetaWindowPatchMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UpdateAppId value)?  updateAppId,TResult Function( UpdateParent value)?  updateParent,TResult Function( UpdateTitle value)?  updateTitle,TResult Function( UpdatePid value)?  updatePid,TResult Function( UpdateWindowClass value)?  updateWindowClass,TResult Function( UpdateStartupId value)?  updateStartupId,TResult Function( UpdateDisplayMode value)?  updateDisplayMode,TResult Function( UpdateMapped value)?  updateMapped,TResult Function( UpdateGeometry value)?  updateGeometry,TResult Function( UpdateNeedDecoration value)?  updateNeedDecoration,TResult Function( UpdateGameModeActivated value)?  updateGameModeActivated,TResult Function( UpdateCurrentOutput value)?  updateCurrentOutput,TResult Function( UpdateScaleRatio value)?  updateScaleRatio,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UpdateAppId() when updateAppId != null:
return updateAppId(_that);case UpdateParent() when updateParent != null:
return updateParent(_that);case UpdateTitle() when updateTitle != null:
return updateTitle(_that);case UpdatePid() when updatePid != null:
return updatePid(_that);case UpdateWindowClass() when updateWindowClass != null:
return updateWindowClass(_that);case UpdateStartupId() when updateStartupId != null:
return updateStartupId(_that);case UpdateDisplayMode() when updateDisplayMode != null:
return updateDisplayMode(_that);case UpdateMapped() when updateMapped != null:
return updateMapped(_that);case UpdateGeometry() when updateGeometry != null:
return updateGeometry(_that);case UpdateNeedDecoration() when updateNeedDecoration != null:
return updateNeedDecoration(_that);case UpdateGameModeActivated() when updateGameModeActivated != null:
return updateGameModeActivated(_that);case UpdateCurrentOutput() when updateCurrentOutput != null:
return updateCurrentOutput(_that);case UpdateScaleRatio() when updateScaleRatio != null:
return updateScaleRatio(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UpdateAppId value)  updateAppId,required TResult Function( UpdateParent value)  updateParent,required TResult Function( UpdateTitle value)  updateTitle,required TResult Function( UpdatePid value)  updatePid,required TResult Function( UpdateWindowClass value)  updateWindowClass,required TResult Function( UpdateStartupId value)  updateStartupId,required TResult Function( UpdateDisplayMode value)  updateDisplayMode,required TResult Function( UpdateMapped value)  updateMapped,required TResult Function( UpdateGeometry value)  updateGeometry,required TResult Function( UpdateNeedDecoration value)  updateNeedDecoration,required TResult Function( UpdateGameModeActivated value)  updateGameModeActivated,required TResult Function( UpdateCurrentOutput value)  updateCurrentOutput,required TResult Function( UpdateScaleRatio value)  updateScaleRatio,}){
final _that = this;
switch (_that) {
case UpdateAppId():
return updateAppId(_that);case UpdateParent():
return updateParent(_that);case UpdateTitle():
return updateTitle(_that);case UpdatePid():
return updatePid(_that);case UpdateWindowClass():
return updateWindowClass(_that);case UpdateStartupId():
return updateStartupId(_that);case UpdateDisplayMode():
return updateDisplayMode(_that);case UpdateMapped():
return updateMapped(_that);case UpdateGeometry():
return updateGeometry(_that);case UpdateNeedDecoration():
return updateNeedDecoration(_that);case UpdateGameModeActivated():
return updateGameModeActivated(_that);case UpdateCurrentOutput():
return updateCurrentOutput(_that);case UpdateScaleRatio():
return updateScaleRatio(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UpdateAppId value)?  updateAppId,TResult? Function( UpdateParent value)?  updateParent,TResult? Function( UpdateTitle value)?  updateTitle,TResult? Function( UpdatePid value)?  updatePid,TResult? Function( UpdateWindowClass value)?  updateWindowClass,TResult? Function( UpdateStartupId value)?  updateStartupId,TResult? Function( UpdateDisplayMode value)?  updateDisplayMode,TResult? Function( UpdateMapped value)?  updateMapped,TResult? Function( UpdateGeometry value)?  updateGeometry,TResult? Function( UpdateNeedDecoration value)?  updateNeedDecoration,TResult? Function( UpdateGameModeActivated value)?  updateGameModeActivated,TResult? Function( UpdateCurrentOutput value)?  updateCurrentOutput,TResult? Function( UpdateScaleRatio value)?  updateScaleRatio,}){
final _that = this;
switch (_that) {
case UpdateAppId() when updateAppId != null:
return updateAppId(_that);case UpdateParent() when updateParent != null:
return updateParent(_that);case UpdateTitle() when updateTitle != null:
return updateTitle(_that);case UpdatePid() when updatePid != null:
return updatePid(_that);case UpdateWindowClass() when updateWindowClass != null:
return updateWindowClass(_that);case UpdateStartupId() when updateStartupId != null:
return updateStartupId(_that);case UpdateDisplayMode() when updateDisplayMode != null:
return updateDisplayMode(_that);case UpdateMapped() when updateMapped != null:
return updateMapped(_that);case UpdateGeometry() when updateGeometry != null:
return updateGeometry(_that);case UpdateNeedDecoration() when updateNeedDecoration != null:
return updateNeedDecoration(_that);case UpdateGameModeActivated() when updateGameModeActivated != null:
return updateGameModeActivated(_that);case UpdateCurrentOutput() when updateCurrentOutput != null:
return updateCurrentOutput(_that);case UpdateScaleRatio() when updateScaleRatio != null:
return updateScaleRatio(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  String? value)?  updateAppId,TResult Function( String id,  String? value)?  updateParent,TResult Function( String id,  String? value)?  updateTitle,TResult Function( String id,  int value)?  updatePid,TResult Function( String id,  String? value)?  updateWindowClass,TResult Function( String id,  String? value)?  updateStartupId,TResult Function( String id,  MetaWindowDisplayMode? value)?  updateDisplayMode,TResult Function( String id,  bool value)?  updateMapped,TResult Function( String id, @RectConverter()  Rect? value)?  updateGeometry,TResult Function( String id,  bool value)?  updateNeedDecoration,TResult Function( String id,  bool value)?  updateGameModeActivated,TResult Function( String id,  String? value)?  updateCurrentOutput,TResult Function( String id,  double value)?  updateScaleRatio,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UpdateAppId() when updateAppId != null:
return updateAppId(_that.id,_that.value);case UpdateParent() when updateParent != null:
return updateParent(_that.id,_that.value);case UpdateTitle() when updateTitle != null:
return updateTitle(_that.id,_that.value);case UpdatePid() when updatePid != null:
return updatePid(_that.id,_that.value);case UpdateWindowClass() when updateWindowClass != null:
return updateWindowClass(_that.id,_that.value);case UpdateStartupId() when updateStartupId != null:
return updateStartupId(_that.id,_that.value);case UpdateDisplayMode() when updateDisplayMode != null:
return updateDisplayMode(_that.id,_that.value);case UpdateMapped() when updateMapped != null:
return updateMapped(_that.id,_that.value);case UpdateGeometry() when updateGeometry != null:
return updateGeometry(_that.id,_that.value);case UpdateNeedDecoration() when updateNeedDecoration != null:
return updateNeedDecoration(_that.id,_that.value);case UpdateGameModeActivated() when updateGameModeActivated != null:
return updateGameModeActivated(_that.id,_that.value);case UpdateCurrentOutput() when updateCurrentOutput != null:
return updateCurrentOutput(_that.id,_that.value);case UpdateScaleRatio() when updateScaleRatio != null:
return updateScaleRatio(_that.id,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  String? value)  updateAppId,required TResult Function( String id,  String? value)  updateParent,required TResult Function( String id,  String? value)  updateTitle,required TResult Function( String id,  int value)  updatePid,required TResult Function( String id,  String? value)  updateWindowClass,required TResult Function( String id,  String? value)  updateStartupId,required TResult Function( String id,  MetaWindowDisplayMode? value)  updateDisplayMode,required TResult Function( String id,  bool value)  updateMapped,required TResult Function( String id, @RectConverter()  Rect? value)  updateGeometry,required TResult Function( String id,  bool value)  updateNeedDecoration,required TResult Function( String id,  bool value)  updateGameModeActivated,required TResult Function( String id,  String? value)  updateCurrentOutput,required TResult Function( String id,  double value)  updateScaleRatio,}) {final _that = this;
switch (_that) {
case UpdateAppId():
return updateAppId(_that.id,_that.value);case UpdateParent():
return updateParent(_that.id,_that.value);case UpdateTitle():
return updateTitle(_that.id,_that.value);case UpdatePid():
return updatePid(_that.id,_that.value);case UpdateWindowClass():
return updateWindowClass(_that.id,_that.value);case UpdateStartupId():
return updateStartupId(_that.id,_that.value);case UpdateDisplayMode():
return updateDisplayMode(_that.id,_that.value);case UpdateMapped():
return updateMapped(_that.id,_that.value);case UpdateGeometry():
return updateGeometry(_that.id,_that.value);case UpdateNeedDecoration():
return updateNeedDecoration(_that.id,_that.value);case UpdateGameModeActivated():
return updateGameModeActivated(_that.id,_that.value);case UpdateCurrentOutput():
return updateCurrentOutput(_that.id,_that.value);case UpdateScaleRatio():
return updateScaleRatio(_that.id,_that.value);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  String? value)?  updateAppId,TResult? Function( String id,  String? value)?  updateParent,TResult? Function( String id,  String? value)?  updateTitle,TResult? Function( String id,  int value)?  updatePid,TResult? Function( String id,  String? value)?  updateWindowClass,TResult? Function( String id,  String? value)?  updateStartupId,TResult? Function( String id,  MetaWindowDisplayMode? value)?  updateDisplayMode,TResult? Function( String id,  bool value)?  updateMapped,TResult? Function( String id, @RectConverter()  Rect? value)?  updateGeometry,TResult? Function( String id,  bool value)?  updateNeedDecoration,TResult? Function( String id,  bool value)?  updateGameModeActivated,TResult? Function( String id,  String? value)?  updateCurrentOutput,TResult? Function( String id,  double value)?  updateScaleRatio,}) {final _that = this;
switch (_that) {
case UpdateAppId() when updateAppId != null:
return updateAppId(_that.id,_that.value);case UpdateParent() when updateParent != null:
return updateParent(_that.id,_that.value);case UpdateTitle() when updateTitle != null:
return updateTitle(_that.id,_that.value);case UpdatePid() when updatePid != null:
return updatePid(_that.id,_that.value);case UpdateWindowClass() when updateWindowClass != null:
return updateWindowClass(_that.id,_that.value);case UpdateStartupId() when updateStartupId != null:
return updateStartupId(_that.id,_that.value);case UpdateDisplayMode() when updateDisplayMode != null:
return updateDisplayMode(_that.id,_that.value);case UpdateMapped() when updateMapped != null:
return updateMapped(_that.id,_that.value);case UpdateGeometry() when updateGeometry != null:
return updateGeometry(_that.id,_that.value);case UpdateNeedDecoration() when updateNeedDecoration != null:
return updateNeedDecoration(_that.id,_that.value);case UpdateGameModeActivated() when updateGameModeActivated != null:
return updateGameModeActivated(_that.id,_that.value);case UpdateCurrentOutput() when updateCurrentOutput != null:
return updateCurrentOutput(_that.id,_that.value);case UpdateScaleRatio() when updateScaleRatio != null:
return updateScaleRatio(_that.id,_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class UpdateAppId implements MetaWindowPatchMessage {
  const UpdateAppId({required this.id, this.value, final  String? $type}): $type = $type ?? 'UpdateAppId';
  factory UpdateAppId.fromJson(Map<String, dynamic> json) => _$UpdateAppIdFromJson(json);

@override final  String id;
@override final  String? value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateAppIdCopyWith<UpdateAppId> get copyWith => _$UpdateAppIdCopyWithImpl<UpdateAppId>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateAppIdToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateAppId&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaWindowPatchMessage.updateAppId(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateAppIdCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
  factory $UpdateAppIdCopyWith(UpdateAppId value, $Res Function(UpdateAppId) _then) = _$UpdateAppIdCopyWithImpl;
@override @useResult
$Res call({
 String id, String? value
});




}
/// @nodoc
class _$UpdateAppIdCopyWithImpl<$Res>
    implements $UpdateAppIdCopyWith<$Res> {
  _$UpdateAppIdCopyWithImpl(this._self, this._then);

  final UpdateAppId _self;
  final $Res Function(UpdateAppId) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = freezed,}) {
  return _then(UpdateAppId(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateParent implements MetaWindowPatchMessage {
  const UpdateParent({required this.id, this.value, final  String? $type}): $type = $type ?? 'UpdateParent';
  factory UpdateParent.fromJson(Map<String, dynamic> json) => _$UpdateParentFromJson(json);

@override final  String id;
@override final  String? value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateParentCopyWith<UpdateParent> get copyWith => _$UpdateParentCopyWithImpl<UpdateParent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateParentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateParent&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaWindowPatchMessage.updateParent(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateParentCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
  factory $UpdateParentCopyWith(UpdateParent value, $Res Function(UpdateParent) _then) = _$UpdateParentCopyWithImpl;
@override @useResult
$Res call({
 String id, String? value
});




}
/// @nodoc
class _$UpdateParentCopyWithImpl<$Res>
    implements $UpdateParentCopyWith<$Res> {
  _$UpdateParentCopyWithImpl(this._self, this._then);

  final UpdateParent _self;
  final $Res Function(UpdateParent) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = freezed,}) {
  return _then(UpdateParent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateTitle implements MetaWindowPatchMessage {
  const UpdateTitle({required this.id, this.value, final  String? $type}): $type = $type ?? 'UpdateTitle';
  factory UpdateTitle.fromJson(Map<String, dynamic> json) => _$UpdateTitleFromJson(json);

@override final  String id;
@override final  String? value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateTitleCopyWith<UpdateTitle> get copyWith => _$UpdateTitleCopyWithImpl<UpdateTitle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateTitleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateTitle&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaWindowPatchMessage.updateTitle(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateTitleCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
  factory $UpdateTitleCopyWith(UpdateTitle value, $Res Function(UpdateTitle) _then) = _$UpdateTitleCopyWithImpl;
@override @useResult
$Res call({
 String id, String? value
});




}
/// @nodoc
class _$UpdateTitleCopyWithImpl<$Res>
    implements $UpdateTitleCopyWith<$Res> {
  _$UpdateTitleCopyWithImpl(this._self, this._then);

  final UpdateTitle _self;
  final $Res Function(UpdateTitle) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = freezed,}) {
  return _then(UpdateTitle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdatePid implements MetaWindowPatchMessage {
  const UpdatePid({required this.id, required this.value, final  String? $type}): $type = $type ?? 'UpdatePid';
  factory UpdatePid.fromJson(Map<String, dynamic> json) => _$UpdatePidFromJson(json);

@override final  String id;
@override final  int value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdatePidCopyWith<UpdatePid> get copyWith => _$UpdatePidCopyWithImpl<UpdatePid>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdatePidToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdatePid&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaWindowPatchMessage.updatePid(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdatePidCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
  factory $UpdatePidCopyWith(UpdatePid value, $Res Function(UpdatePid) _then) = _$UpdatePidCopyWithImpl;
@override @useResult
$Res call({
 String id, int value
});




}
/// @nodoc
class _$UpdatePidCopyWithImpl<$Res>
    implements $UpdatePidCopyWith<$Res> {
  _$UpdatePidCopyWithImpl(this._self, this._then);

  final UpdatePid _self;
  final $Res Function(UpdatePid) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = null,}) {
  return _then(UpdatePid(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateWindowClass implements MetaWindowPatchMessage {
  const UpdateWindowClass({required this.id, this.value, final  String? $type}): $type = $type ?? 'UpdateWindowClass';
  factory UpdateWindowClass.fromJson(Map<String, dynamic> json) => _$UpdateWindowClassFromJson(json);

@override final  String id;
@override final  String? value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateWindowClassCopyWith<UpdateWindowClass> get copyWith => _$UpdateWindowClassCopyWithImpl<UpdateWindowClass>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateWindowClassToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateWindowClass&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaWindowPatchMessage.updateWindowClass(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateWindowClassCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
  factory $UpdateWindowClassCopyWith(UpdateWindowClass value, $Res Function(UpdateWindowClass) _then) = _$UpdateWindowClassCopyWithImpl;
@override @useResult
$Res call({
 String id, String? value
});




}
/// @nodoc
class _$UpdateWindowClassCopyWithImpl<$Res>
    implements $UpdateWindowClassCopyWith<$Res> {
  _$UpdateWindowClassCopyWithImpl(this._self, this._then);

  final UpdateWindowClass _self;
  final $Res Function(UpdateWindowClass) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = freezed,}) {
  return _then(UpdateWindowClass(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateStartupId implements MetaWindowPatchMessage {
  const UpdateStartupId({required this.id, this.value, final  String? $type}): $type = $type ?? 'UpdateStartupId';
  factory UpdateStartupId.fromJson(Map<String, dynamic> json) => _$UpdateStartupIdFromJson(json);

@override final  String id;
@override final  String? value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateStartupIdCopyWith<UpdateStartupId> get copyWith => _$UpdateStartupIdCopyWithImpl<UpdateStartupId>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateStartupIdToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateStartupId&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaWindowPatchMessage.updateStartupId(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateStartupIdCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
  factory $UpdateStartupIdCopyWith(UpdateStartupId value, $Res Function(UpdateStartupId) _then) = _$UpdateStartupIdCopyWithImpl;
@override @useResult
$Res call({
 String id, String? value
});




}
/// @nodoc
class _$UpdateStartupIdCopyWithImpl<$Res>
    implements $UpdateStartupIdCopyWith<$Res> {
  _$UpdateStartupIdCopyWithImpl(this._self, this._then);

  final UpdateStartupId _self;
  final $Res Function(UpdateStartupId) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = freezed,}) {
  return _then(UpdateStartupId(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateDisplayMode implements MetaWindowPatchMessage {
  const UpdateDisplayMode({required this.id, this.value, final  String? $type}): $type = $type ?? 'UpdateDisplayMode';
  factory UpdateDisplayMode.fromJson(Map<String, dynamic> json) => _$UpdateDisplayModeFromJson(json);

@override final  String id;
@override final  MetaWindowDisplayMode? value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateDisplayModeCopyWith<UpdateDisplayMode> get copyWith => _$UpdateDisplayModeCopyWithImpl<UpdateDisplayMode>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateDisplayModeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateDisplayMode&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaWindowPatchMessage.updateDisplayMode(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateDisplayModeCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
  factory $UpdateDisplayModeCopyWith(UpdateDisplayMode value, $Res Function(UpdateDisplayMode) _then) = _$UpdateDisplayModeCopyWithImpl;
@override @useResult
$Res call({
 String id, MetaWindowDisplayMode? value
});




}
/// @nodoc
class _$UpdateDisplayModeCopyWithImpl<$Res>
    implements $UpdateDisplayModeCopyWith<$Res> {
  _$UpdateDisplayModeCopyWithImpl(this._self, this._then);

  final UpdateDisplayMode _self;
  final $Res Function(UpdateDisplayMode) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = freezed,}) {
  return _then(UpdateDisplayMode(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as MetaWindowDisplayMode?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateMapped implements MetaWindowPatchMessage {
  const UpdateMapped({required this.id, required this.value, final  String? $type}): $type = $type ?? 'UpdateMapped';
  factory UpdateMapped.fromJson(Map<String, dynamic> json) => _$UpdateMappedFromJson(json);

@override final  String id;
@override final  bool value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateMappedCopyWith<UpdateMapped> get copyWith => _$UpdateMappedCopyWithImpl<UpdateMapped>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateMappedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateMapped&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaWindowPatchMessage.updateMapped(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateMappedCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
  factory $UpdateMappedCopyWith(UpdateMapped value, $Res Function(UpdateMapped) _then) = _$UpdateMappedCopyWithImpl;
@override @useResult
$Res call({
 String id, bool value
});




}
/// @nodoc
class _$UpdateMappedCopyWithImpl<$Res>
    implements $UpdateMappedCopyWith<$Res> {
  _$UpdateMappedCopyWithImpl(this._self, this._then);

  final UpdateMapped _self;
  final $Res Function(UpdateMapped) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = null,}) {
  return _then(UpdateMapped(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateGeometry implements MetaWindowPatchMessage {
  const UpdateGeometry({required this.id, @RectConverter() this.value, final  String? $type}): $type = $type ?? 'UpdateGeometry';
  factory UpdateGeometry.fromJson(Map<String, dynamic> json) => _$UpdateGeometryFromJson(json);

@override final  String id;
@override@RectConverter() final  Rect? value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
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
  return 'MetaWindowPatchMessage.updateGeometry(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateGeometryCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
  factory $UpdateGeometryCopyWith(UpdateGeometry value, $Res Function(UpdateGeometry) _then) = _$UpdateGeometryCopyWithImpl;
@override @useResult
$Res call({
 String id,@RectConverter() Rect? value
});




}
/// @nodoc
class _$UpdateGeometryCopyWithImpl<$Res>
    implements $UpdateGeometryCopyWith<$Res> {
  _$UpdateGeometryCopyWithImpl(this._self, this._then);

  final UpdateGeometry _self;
  final $Res Function(UpdateGeometry) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = freezed,}) {
  return _then(UpdateGeometry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as Rect?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateNeedDecoration implements MetaWindowPatchMessage {
  const UpdateNeedDecoration({required this.id, required this.value, final  String? $type}): $type = $type ?? 'UpdateNeedDecoration';
  factory UpdateNeedDecoration.fromJson(Map<String, dynamic> json) => _$UpdateNeedDecorationFromJson(json);

@override final  String id;
@override final  bool value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateNeedDecorationCopyWith<UpdateNeedDecoration> get copyWith => _$UpdateNeedDecorationCopyWithImpl<UpdateNeedDecoration>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateNeedDecorationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateNeedDecoration&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaWindowPatchMessage.updateNeedDecoration(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateNeedDecorationCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
  factory $UpdateNeedDecorationCopyWith(UpdateNeedDecoration value, $Res Function(UpdateNeedDecoration) _then) = _$UpdateNeedDecorationCopyWithImpl;
@override @useResult
$Res call({
 String id, bool value
});




}
/// @nodoc
class _$UpdateNeedDecorationCopyWithImpl<$Res>
    implements $UpdateNeedDecorationCopyWith<$Res> {
  _$UpdateNeedDecorationCopyWithImpl(this._self, this._then);

  final UpdateNeedDecoration _self;
  final $Res Function(UpdateNeedDecoration) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = null,}) {
  return _then(UpdateNeedDecoration(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateGameModeActivated implements MetaWindowPatchMessage {
  const UpdateGameModeActivated({required this.id, required this.value, final  String? $type}): $type = $type ?? 'UpdateGameModeActivated';
  factory UpdateGameModeActivated.fromJson(Map<String, dynamic> json) => _$UpdateGameModeActivatedFromJson(json);

@override final  String id;
@override final  bool value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateGameModeActivatedCopyWith<UpdateGameModeActivated> get copyWith => _$UpdateGameModeActivatedCopyWithImpl<UpdateGameModeActivated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateGameModeActivatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateGameModeActivated&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaWindowPatchMessage.updateGameModeActivated(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateGameModeActivatedCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
  factory $UpdateGameModeActivatedCopyWith(UpdateGameModeActivated value, $Res Function(UpdateGameModeActivated) _then) = _$UpdateGameModeActivatedCopyWithImpl;
@override @useResult
$Res call({
 String id, bool value
});




}
/// @nodoc
class _$UpdateGameModeActivatedCopyWithImpl<$Res>
    implements $UpdateGameModeActivatedCopyWith<$Res> {
  _$UpdateGameModeActivatedCopyWithImpl(this._self, this._then);

  final UpdateGameModeActivated _self;
  final $Res Function(UpdateGameModeActivated) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = null,}) {
  return _then(UpdateGameModeActivated(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateCurrentOutput implements MetaWindowPatchMessage {
  const UpdateCurrentOutput({required this.id, this.value, final  String? $type}): $type = $type ?? 'UpdateCurrentOutput';
  factory UpdateCurrentOutput.fromJson(Map<String, dynamic> json) => _$UpdateCurrentOutputFromJson(json);

@override final  String id;
@override final  String? value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateCurrentOutputCopyWith<UpdateCurrentOutput> get copyWith => _$UpdateCurrentOutputCopyWithImpl<UpdateCurrentOutput>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateCurrentOutputToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateCurrentOutput&&(identical(other.id, id) || other.id == id)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,value);

@override
String toString() {
  return 'MetaWindowPatchMessage.updateCurrentOutput(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateCurrentOutputCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
  factory $UpdateCurrentOutputCopyWith(UpdateCurrentOutput value, $Res Function(UpdateCurrentOutput) _then) = _$UpdateCurrentOutputCopyWithImpl;
@override @useResult
$Res call({
 String id, String? value
});




}
/// @nodoc
class _$UpdateCurrentOutputCopyWithImpl<$Res>
    implements $UpdateCurrentOutputCopyWith<$Res> {
  _$UpdateCurrentOutputCopyWithImpl(this._self, this._then);

  final UpdateCurrentOutput _self;
  final $Res Function(UpdateCurrentOutput) _then;

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = freezed,}) {
  return _then(UpdateCurrentOutput(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UpdateScaleRatio implements MetaWindowPatchMessage {
  const UpdateScaleRatio({required this.id, required this.value, final  String? $type}): $type = $type ?? 'UpdateScaleRatio';
  factory UpdateScaleRatio.fromJson(Map<String, dynamic> json) => _$UpdateScaleRatioFromJson(json);

@override final  String id;
@override final  double value;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MetaWindowPatchMessage
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
  return 'MetaWindowPatchMessage.updateScaleRatio(id: $id, value: $value)';
}


}

/// @nodoc
abstract mixin class $UpdateScaleRatioCopyWith<$Res> implements $MetaWindowPatchMessageCopyWith<$Res> {
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

/// Create a copy of MetaWindowPatchMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? value = null,}) {
  return _then(UpdateScaleRatio(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on

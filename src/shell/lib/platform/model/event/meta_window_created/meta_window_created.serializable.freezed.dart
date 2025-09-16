// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meta_window_created.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MetaWindowCreatedMessage {

 String get id; int get pid; bool get mapped; int get surfaceId; bool get needDecoration; bool get gameModeActivated; double get scaleRatio; String? get appId; String? get parent; String? get displayMode; String? get title; String? get windowClass; String? get startupId;@RectConverter() Rect? get geometry;
/// Create a copy of MetaWindowCreatedMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaWindowCreatedMessageCopyWith<MetaWindowCreatedMessage> get copyWith => _$MetaWindowCreatedMessageCopyWithImpl<MetaWindowCreatedMessage>(this as MetaWindowCreatedMessage, _$identity);

  /// Serializes this MetaWindowCreatedMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MetaWindowCreatedMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.mapped, mapped) || other.mapped == mapped)&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.needDecoration, needDecoration) || other.needDecoration == needDecoration)&&(identical(other.gameModeActivated, gameModeActivated) || other.gameModeActivated == gameModeActivated)&&(identical(other.scaleRatio, scaleRatio) || other.scaleRatio == scaleRatio)&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.displayMode, displayMode) || other.displayMode == displayMode)&&(identical(other.title, title) || other.title == title)&&(identical(other.windowClass, windowClass) || other.windowClass == windowClass)&&(identical(other.startupId, startupId) || other.startupId == startupId)&&(identical(other.geometry, geometry) || other.geometry == geometry));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,pid,mapped,surfaceId,needDecoration,gameModeActivated,scaleRatio,appId,parent,displayMode,title,windowClass,startupId,geometry);

@override
String toString() {
  return 'MetaWindowCreatedMessage(id: $id, pid: $pid, mapped: $mapped, surfaceId: $surfaceId, needDecoration: $needDecoration, gameModeActivated: $gameModeActivated, scaleRatio: $scaleRatio, appId: $appId, parent: $parent, displayMode: $displayMode, title: $title, windowClass: $windowClass, startupId: $startupId, geometry: $geometry)';
}


}

/// @nodoc
abstract mixin class $MetaWindowCreatedMessageCopyWith<$Res>  {
  factory $MetaWindowCreatedMessageCopyWith(MetaWindowCreatedMessage value, $Res Function(MetaWindowCreatedMessage) _then) = _$MetaWindowCreatedMessageCopyWithImpl;
@useResult
$Res call({
 String id, int pid, bool mapped, int surfaceId, bool needDecoration, bool gameModeActivated, double scaleRatio, String? appId, String? parent, String? displayMode, String? title, String? windowClass, String? startupId,@RectConverter() Rect? geometry
});




}
/// @nodoc
class _$MetaWindowCreatedMessageCopyWithImpl<$Res>
    implements $MetaWindowCreatedMessageCopyWith<$Res> {
  _$MetaWindowCreatedMessageCopyWithImpl(this._self, this._then);

  final MetaWindowCreatedMessage _self;
  final $Res Function(MetaWindowCreatedMessage) _then;

/// Create a copy of MetaWindowCreatedMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? pid = null,Object? mapped = null,Object? surfaceId = null,Object? needDecoration = null,Object? gameModeActivated = null,Object? scaleRatio = null,Object? appId = freezed,Object? parent = freezed,Object? displayMode = freezed,Object? title = freezed,Object? windowClass = freezed,Object? startupId = freezed,Object? geometry = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,pid: null == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int,mapped: null == mapped ? _self.mapped : mapped // ignore: cast_nullable_to_non_nullable
as bool,surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as int,needDecoration: null == needDecoration ? _self.needDecoration : needDecoration // ignore: cast_nullable_to_non_nullable
as bool,gameModeActivated: null == gameModeActivated ? _self.gameModeActivated : gameModeActivated // ignore: cast_nullable_to_non_nullable
as bool,scaleRatio: null == scaleRatio ? _self.scaleRatio : scaleRatio // ignore: cast_nullable_to_non_nullable
as double,appId: freezed == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String?,parent: freezed == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as String?,displayMode: freezed == displayMode ? _self.displayMode : displayMode // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,windowClass: freezed == windowClass ? _self.windowClass : windowClass // ignore: cast_nullable_to_non_nullable
as String?,startupId: freezed == startupId ? _self.startupId : startupId // ignore: cast_nullable_to_non_nullable
as String?,geometry: freezed == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as Rect?,
  ));
}

}


/// Adds pattern-matching-related methods to [MetaWindowCreatedMessage].
extension MetaWindowCreatedMessagePatterns on MetaWindowCreatedMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MetaWindowCreatedMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MetaWindowCreatedMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MetaWindowCreatedMessage value)  $default,){
final _that = this;
switch (_that) {
case _MetaWindowCreatedMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MetaWindowCreatedMessage value)?  $default,){
final _that = this;
switch (_that) {
case _MetaWindowCreatedMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int pid,  bool mapped,  int surfaceId,  bool needDecoration,  bool gameModeActivated,  double scaleRatio,  String? appId,  String? parent,  String? displayMode,  String? title,  String? windowClass,  String? startupId, @RectConverter()  Rect? geometry)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MetaWindowCreatedMessage() when $default != null:
return $default(_that.id,_that.pid,_that.mapped,_that.surfaceId,_that.needDecoration,_that.gameModeActivated,_that.scaleRatio,_that.appId,_that.parent,_that.displayMode,_that.title,_that.windowClass,_that.startupId,_that.geometry);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int pid,  bool mapped,  int surfaceId,  bool needDecoration,  bool gameModeActivated,  double scaleRatio,  String? appId,  String? parent,  String? displayMode,  String? title,  String? windowClass,  String? startupId, @RectConverter()  Rect? geometry)  $default,) {final _that = this;
switch (_that) {
case _MetaWindowCreatedMessage():
return $default(_that.id,_that.pid,_that.mapped,_that.surfaceId,_that.needDecoration,_that.gameModeActivated,_that.scaleRatio,_that.appId,_that.parent,_that.displayMode,_that.title,_that.windowClass,_that.startupId,_that.geometry);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int pid,  bool mapped,  int surfaceId,  bool needDecoration,  bool gameModeActivated,  double scaleRatio,  String? appId,  String? parent,  String? displayMode,  String? title,  String? windowClass,  String? startupId, @RectConverter()  Rect? geometry)?  $default,) {final _that = this;
switch (_that) {
case _MetaWindowCreatedMessage() when $default != null:
return $default(_that.id,_that.pid,_that.mapped,_that.surfaceId,_that.needDecoration,_that.gameModeActivated,_that.scaleRatio,_that.appId,_that.parent,_that.displayMode,_that.title,_that.windowClass,_that.startupId,_that.geometry);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MetaWindowCreatedMessage implements MetaWindowCreatedMessage {
   _MetaWindowCreatedMessage({required this.id, required this.pid, required this.mapped, required this.surfaceId, required this.needDecoration, required this.gameModeActivated, required this.scaleRatio, this.appId, this.parent, this.displayMode, this.title, this.windowClass, this.startupId, @RectConverter() this.geometry});
  factory _MetaWindowCreatedMessage.fromJson(Map<String, dynamic> json) => _$MetaWindowCreatedMessageFromJson(json);

@override final  String id;
@override final  int pid;
@override final  bool mapped;
@override final  int surfaceId;
@override final  bool needDecoration;
@override final  bool gameModeActivated;
@override final  double scaleRatio;
@override final  String? appId;
@override final  String? parent;
@override final  String? displayMode;
@override final  String? title;
@override final  String? windowClass;
@override final  String? startupId;
@override@RectConverter() final  Rect? geometry;

/// Create a copy of MetaWindowCreatedMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MetaWindowCreatedMessageCopyWith<_MetaWindowCreatedMessage> get copyWith => __$MetaWindowCreatedMessageCopyWithImpl<_MetaWindowCreatedMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaWindowCreatedMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MetaWindowCreatedMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.mapped, mapped) || other.mapped == mapped)&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.needDecoration, needDecoration) || other.needDecoration == needDecoration)&&(identical(other.gameModeActivated, gameModeActivated) || other.gameModeActivated == gameModeActivated)&&(identical(other.scaleRatio, scaleRatio) || other.scaleRatio == scaleRatio)&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.displayMode, displayMode) || other.displayMode == displayMode)&&(identical(other.title, title) || other.title == title)&&(identical(other.windowClass, windowClass) || other.windowClass == windowClass)&&(identical(other.startupId, startupId) || other.startupId == startupId)&&(identical(other.geometry, geometry) || other.geometry == geometry));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,pid,mapped,surfaceId,needDecoration,gameModeActivated,scaleRatio,appId,parent,displayMode,title,windowClass,startupId,geometry);

@override
String toString() {
  return 'MetaWindowCreatedMessage(id: $id, pid: $pid, mapped: $mapped, surfaceId: $surfaceId, needDecoration: $needDecoration, gameModeActivated: $gameModeActivated, scaleRatio: $scaleRatio, appId: $appId, parent: $parent, displayMode: $displayMode, title: $title, windowClass: $windowClass, startupId: $startupId, geometry: $geometry)';
}


}

/// @nodoc
abstract mixin class _$MetaWindowCreatedMessageCopyWith<$Res> implements $MetaWindowCreatedMessageCopyWith<$Res> {
  factory _$MetaWindowCreatedMessageCopyWith(_MetaWindowCreatedMessage value, $Res Function(_MetaWindowCreatedMessage) _then) = __$MetaWindowCreatedMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, int pid, bool mapped, int surfaceId, bool needDecoration, bool gameModeActivated, double scaleRatio, String? appId, String? parent, String? displayMode, String? title, String? windowClass, String? startupId,@RectConverter() Rect? geometry
});




}
/// @nodoc
class __$MetaWindowCreatedMessageCopyWithImpl<$Res>
    implements _$MetaWindowCreatedMessageCopyWith<$Res> {
  __$MetaWindowCreatedMessageCopyWithImpl(this._self, this._then);

  final _MetaWindowCreatedMessage _self;
  final $Res Function(_MetaWindowCreatedMessage) _then;

/// Create a copy of MetaWindowCreatedMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? pid = null,Object? mapped = null,Object? surfaceId = null,Object? needDecoration = null,Object? gameModeActivated = null,Object? scaleRatio = null,Object? appId = freezed,Object? parent = freezed,Object? displayMode = freezed,Object? title = freezed,Object? windowClass = freezed,Object? startupId = freezed,Object? geometry = freezed,}) {
  return _then(_MetaWindowCreatedMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,pid: null == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int,mapped: null == mapped ? _self.mapped : mapped // ignore: cast_nullable_to_non_nullable
as bool,surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as int,needDecoration: null == needDecoration ? _self.needDecoration : needDecoration // ignore: cast_nullable_to_non_nullable
as bool,gameModeActivated: null == gameModeActivated ? _self.gameModeActivated : gameModeActivated // ignore: cast_nullable_to_non_nullable
as bool,scaleRatio: null == scaleRatio ? _self.scaleRatio : scaleRatio // ignore: cast_nullable_to_non_nullable
as double,appId: freezed == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String?,parent: freezed == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as String?,displayMode: freezed == displayMode ? _self.displayMode : displayMode // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,windowClass: freezed == windowClass ? _self.windowClass : windowClass // ignore: cast_nullable_to_non_nullable
as String?,startupId: freezed == startupId ? _self.startupId : startupId // ignore: cast_nullable_to_non_nullable
as String?,geometry: freezed == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as Rect?,
  ));
}


}

// dart format on

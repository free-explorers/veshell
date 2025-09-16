// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_hints.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationHints {

 bool? get actionIcons; String? get category; String? get desktopEntry; List<int>? get imageData; String? get imagePath; List<int>? get iconData; bool? get resident; String? get soundFile; String? get soundName; bool? get suppressSound; bool? get transient; int? get x; int? get y; int? get urgency;
/// Create a copy of NotificationHints
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationHintsCopyWith<NotificationHints> get copyWith => _$NotificationHintsCopyWithImpl<NotificationHints>(this as NotificationHints, _$identity);

  /// Serializes this NotificationHints to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationHints&&(identical(other.actionIcons, actionIcons) || other.actionIcons == actionIcons)&&(identical(other.category, category) || other.category == category)&&(identical(other.desktopEntry, desktopEntry) || other.desktopEntry == desktopEntry)&&const DeepCollectionEquality().equals(other.imageData, imageData)&&(identical(other.imagePath, imagePath) || other.imagePath == imagePath)&&const DeepCollectionEquality().equals(other.iconData, iconData)&&(identical(other.resident, resident) || other.resident == resident)&&(identical(other.soundFile, soundFile) || other.soundFile == soundFile)&&(identical(other.soundName, soundName) || other.soundName == soundName)&&(identical(other.suppressSound, suppressSound) || other.suppressSound == suppressSound)&&(identical(other.transient, transient) || other.transient == transient)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.urgency, urgency) || other.urgency == urgency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,actionIcons,category,desktopEntry,const DeepCollectionEquality().hash(imageData),imagePath,const DeepCollectionEquality().hash(iconData),resident,soundFile,soundName,suppressSound,transient,x,y,urgency);

@override
String toString() {
  return 'NotificationHints(actionIcons: $actionIcons, category: $category, desktopEntry: $desktopEntry, imageData: $imageData, imagePath: $imagePath, iconData: $iconData, resident: $resident, soundFile: $soundFile, soundName: $soundName, suppressSound: $suppressSound, transient: $transient, x: $x, y: $y, urgency: $urgency)';
}


}

/// @nodoc
abstract mixin class $NotificationHintsCopyWith<$Res>  {
  factory $NotificationHintsCopyWith(NotificationHints value, $Res Function(NotificationHints) _then) = _$NotificationHintsCopyWithImpl;
@useResult
$Res call({
 bool? actionIcons, String? category, String? desktopEntry, List<int>? imageData, String? imagePath, List<int>? iconData, bool? resident, String? soundFile, String? soundName, bool? suppressSound, bool? transient, int? x, int? y, int? urgency
});




}
/// @nodoc
class _$NotificationHintsCopyWithImpl<$Res>
    implements $NotificationHintsCopyWith<$Res> {
  _$NotificationHintsCopyWithImpl(this._self, this._then);

  final NotificationHints _self;
  final $Res Function(NotificationHints) _then;

/// Create a copy of NotificationHints
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? actionIcons = freezed,Object? category = freezed,Object? desktopEntry = freezed,Object? imageData = freezed,Object? imagePath = freezed,Object? iconData = freezed,Object? resident = freezed,Object? soundFile = freezed,Object? soundName = freezed,Object? suppressSound = freezed,Object? transient = freezed,Object? x = freezed,Object? y = freezed,Object? urgency = freezed,}) {
  return _then(_self.copyWith(
actionIcons: freezed == actionIcons ? _self.actionIcons : actionIcons // ignore: cast_nullable_to_non_nullable
as bool?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,desktopEntry: freezed == desktopEntry ? _self.desktopEntry : desktopEntry // ignore: cast_nullable_to_non_nullable
as String?,imageData: freezed == imageData ? _self.imageData : imageData // ignore: cast_nullable_to_non_nullable
as List<int>?,imagePath: freezed == imagePath ? _self.imagePath : imagePath // ignore: cast_nullable_to_non_nullable
as String?,iconData: freezed == iconData ? _self.iconData : iconData // ignore: cast_nullable_to_non_nullable
as List<int>?,resident: freezed == resident ? _self.resident : resident // ignore: cast_nullable_to_non_nullable
as bool?,soundFile: freezed == soundFile ? _self.soundFile : soundFile // ignore: cast_nullable_to_non_nullable
as String?,soundName: freezed == soundName ? _self.soundName : soundName // ignore: cast_nullable_to_non_nullable
as String?,suppressSound: freezed == suppressSound ? _self.suppressSound : suppressSound // ignore: cast_nullable_to_non_nullable
as bool?,transient: freezed == transient ? _self.transient : transient // ignore: cast_nullable_to_non_nullable
as bool?,x: freezed == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int?,y: freezed == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int?,urgency: freezed == urgency ? _self.urgency : urgency // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationHints].
extension NotificationHintsPatterns on NotificationHints {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationHints value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationHints() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationHints value)  $default,){
final _that = this;
switch (_that) {
case _NotificationHints():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationHints value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationHints() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool? actionIcons,  String? category,  String? desktopEntry,  List<int>? imageData,  String? imagePath,  List<int>? iconData,  bool? resident,  String? soundFile,  String? soundName,  bool? suppressSound,  bool? transient,  int? x,  int? y,  int? urgency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationHints() when $default != null:
return $default(_that.actionIcons,_that.category,_that.desktopEntry,_that.imageData,_that.imagePath,_that.iconData,_that.resident,_that.soundFile,_that.soundName,_that.suppressSound,_that.transient,_that.x,_that.y,_that.urgency);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool? actionIcons,  String? category,  String? desktopEntry,  List<int>? imageData,  String? imagePath,  List<int>? iconData,  bool? resident,  String? soundFile,  String? soundName,  bool? suppressSound,  bool? transient,  int? x,  int? y,  int? urgency)  $default,) {final _that = this;
switch (_that) {
case _NotificationHints():
return $default(_that.actionIcons,_that.category,_that.desktopEntry,_that.imageData,_that.imagePath,_that.iconData,_that.resident,_that.soundFile,_that.soundName,_that.suppressSound,_that.transient,_that.x,_that.y,_that.urgency);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool? actionIcons,  String? category,  String? desktopEntry,  List<int>? imageData,  String? imagePath,  List<int>? iconData,  bool? resident,  String? soundFile,  String? soundName,  bool? suppressSound,  bool? transient,  int? x,  int? y,  int? urgency)?  $default,) {final _that = this;
switch (_that) {
case _NotificationHints() when $default != null:
return $default(_that.actionIcons,_that.category,_that.desktopEntry,_that.imageData,_that.imagePath,_that.iconData,_that.resident,_that.soundFile,_that.soundName,_that.suppressSound,_that.transient,_that.x,_that.y,_that.urgency);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationHints implements NotificationHints {
  const _NotificationHints({this.actionIcons, this.category, this.desktopEntry, final  List<int>? imageData, this.imagePath, final  List<int>? iconData, this.resident, this.soundFile, this.soundName, this.suppressSound, this.transient, this.x, this.y, this.urgency}): _imageData = imageData,_iconData = iconData;
  factory _NotificationHints.fromJson(Map<String, dynamic> json) => _$NotificationHintsFromJson(json);

@override final  bool? actionIcons;
@override final  String? category;
@override final  String? desktopEntry;
 final  List<int>? _imageData;
@override List<int>? get imageData {
  final value = _imageData;
  if (value == null) return null;
  if (_imageData is EqualUnmodifiableListView) return _imageData;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? imagePath;
 final  List<int>? _iconData;
@override List<int>? get iconData {
  final value = _iconData;
  if (value == null) return null;
  if (_iconData is EqualUnmodifiableListView) return _iconData;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  bool? resident;
@override final  String? soundFile;
@override final  String? soundName;
@override final  bool? suppressSound;
@override final  bool? transient;
@override final  int? x;
@override final  int? y;
@override final  int? urgency;

/// Create a copy of NotificationHints
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationHintsCopyWith<_NotificationHints> get copyWith => __$NotificationHintsCopyWithImpl<_NotificationHints>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationHintsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationHints&&(identical(other.actionIcons, actionIcons) || other.actionIcons == actionIcons)&&(identical(other.category, category) || other.category == category)&&(identical(other.desktopEntry, desktopEntry) || other.desktopEntry == desktopEntry)&&const DeepCollectionEquality().equals(other._imageData, _imageData)&&(identical(other.imagePath, imagePath) || other.imagePath == imagePath)&&const DeepCollectionEquality().equals(other._iconData, _iconData)&&(identical(other.resident, resident) || other.resident == resident)&&(identical(other.soundFile, soundFile) || other.soundFile == soundFile)&&(identical(other.soundName, soundName) || other.soundName == soundName)&&(identical(other.suppressSound, suppressSound) || other.suppressSound == suppressSound)&&(identical(other.transient, transient) || other.transient == transient)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.urgency, urgency) || other.urgency == urgency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,actionIcons,category,desktopEntry,const DeepCollectionEquality().hash(_imageData),imagePath,const DeepCollectionEquality().hash(_iconData),resident,soundFile,soundName,suppressSound,transient,x,y,urgency);

@override
String toString() {
  return 'NotificationHints(actionIcons: $actionIcons, category: $category, desktopEntry: $desktopEntry, imageData: $imageData, imagePath: $imagePath, iconData: $iconData, resident: $resident, soundFile: $soundFile, soundName: $soundName, suppressSound: $suppressSound, transient: $transient, x: $x, y: $y, urgency: $urgency)';
}


}

/// @nodoc
abstract mixin class _$NotificationHintsCopyWith<$Res> implements $NotificationHintsCopyWith<$Res> {
  factory _$NotificationHintsCopyWith(_NotificationHints value, $Res Function(_NotificationHints) _then) = __$NotificationHintsCopyWithImpl;
@override @useResult
$Res call({
 bool? actionIcons, String? category, String? desktopEntry, List<int>? imageData, String? imagePath, List<int>? iconData, bool? resident, String? soundFile, String? soundName, bool? suppressSound, bool? transient, int? x, int? y, int? urgency
});




}
/// @nodoc
class __$NotificationHintsCopyWithImpl<$Res>
    implements _$NotificationHintsCopyWith<$Res> {
  __$NotificationHintsCopyWithImpl(this._self, this._then);

  final _NotificationHints _self;
  final $Res Function(_NotificationHints) _then;

/// Create a copy of NotificationHints
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? actionIcons = freezed,Object? category = freezed,Object? desktopEntry = freezed,Object? imageData = freezed,Object? imagePath = freezed,Object? iconData = freezed,Object? resident = freezed,Object? soundFile = freezed,Object? soundName = freezed,Object? suppressSound = freezed,Object? transient = freezed,Object? x = freezed,Object? y = freezed,Object? urgency = freezed,}) {
  return _then(_NotificationHints(
actionIcons: freezed == actionIcons ? _self.actionIcons : actionIcons // ignore: cast_nullable_to_non_nullable
as bool?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,desktopEntry: freezed == desktopEntry ? _self.desktopEntry : desktopEntry // ignore: cast_nullable_to_non_nullable
as String?,imageData: freezed == imageData ? _self._imageData : imageData // ignore: cast_nullable_to_non_nullable
as List<int>?,imagePath: freezed == imagePath ? _self.imagePath : imagePath // ignore: cast_nullable_to_non_nullable
as String?,iconData: freezed == iconData ? _self._iconData : iconData // ignore: cast_nullable_to_non_nullable
as List<int>?,resident: freezed == resident ? _self.resident : resident // ignore: cast_nullable_to_non_nullable
as bool?,soundFile: freezed == soundFile ? _self.soundFile : soundFile // ignore: cast_nullable_to_non_nullable
as String?,soundName: freezed == soundName ? _self.soundName : soundName // ignore: cast_nullable_to_non_nullable
as String?,suppressSound: freezed == suppressSound ? _self.suppressSound : suppressSound // ignore: cast_nullable_to_non_nullable
as bool?,transient: freezed == transient ? _self.transient : transient // ignore: cast_nullable_to_non_nullable
as bool?,x: freezed == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int?,y: freezed == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int?,urgency: freezed == urgency ? _self.urgency : urgency // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on

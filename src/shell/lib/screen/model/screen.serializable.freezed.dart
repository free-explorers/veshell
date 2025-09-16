// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'screen.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Screen {

 ScreenId get screenId; IList<WorkspaceId> get workspaceList; int get selectedIndex; String? get label;
/// Create a copy of Screen
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScreenCopyWith<Screen> get copyWith => _$ScreenCopyWithImpl<Screen>(this as Screen, _$identity);

  /// Serializes this Screen to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Screen&&(identical(other.screenId, screenId) || other.screenId == screenId)&&const DeepCollectionEquality().equals(other.workspaceList, workspaceList)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,screenId,const DeepCollectionEquality().hash(workspaceList),selectedIndex,label);

@override
String toString() {
  return 'Screen(screenId: $screenId, workspaceList: $workspaceList, selectedIndex: $selectedIndex, label: $label)';
}


}

/// @nodoc
abstract mixin class $ScreenCopyWith<$Res>  {
  factory $ScreenCopyWith(Screen value, $Res Function(Screen) _then) = _$ScreenCopyWithImpl;
@useResult
$Res call({
 ScreenId screenId, IList<WorkspaceId> workspaceList, int selectedIndex, String? label
});




}
/// @nodoc
class _$ScreenCopyWithImpl<$Res>
    implements $ScreenCopyWith<$Res> {
  _$ScreenCopyWithImpl(this._self, this._then);

  final Screen _self;
  final $Res Function(Screen) _then;

/// Create a copy of Screen
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? screenId = null,Object? workspaceList = null,Object? selectedIndex = null,Object? label = freezed,}) {
  return _then(_self.copyWith(
screenId: null == screenId ? _self.screenId : screenId // ignore: cast_nullable_to_non_nullable
as ScreenId,workspaceList: null == workspaceList ? _self.workspaceList : workspaceList // ignore: cast_nullable_to_non_nullable
as IList<WorkspaceId>,selectedIndex: null == selectedIndex ? _self.selectedIndex : selectedIndex // ignore: cast_nullable_to_non_nullable
as int,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Screen].
extension ScreenPatterns on Screen {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Screen value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Screen() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Screen value)  $default,){
final _that = this;
switch (_that) {
case _Screen():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Screen value)?  $default,){
final _that = this;
switch (_that) {
case _Screen() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ScreenId screenId,  IList<WorkspaceId> workspaceList,  int selectedIndex,  String? label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Screen() when $default != null:
return $default(_that.screenId,_that.workspaceList,_that.selectedIndex,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ScreenId screenId,  IList<WorkspaceId> workspaceList,  int selectedIndex,  String? label)  $default,) {final _that = this;
switch (_that) {
case _Screen():
return $default(_that.screenId,_that.workspaceList,_that.selectedIndex,_that.label);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ScreenId screenId,  IList<WorkspaceId> workspaceList,  int selectedIndex,  String? label)?  $default,) {final _that = this;
switch (_that) {
case _Screen() when $default != null:
return $default(_that.screenId,_that.workspaceList,_that.selectedIndex,_that.label);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Screen extends Screen {
   _Screen({required this.screenId, required this.workspaceList, required this.selectedIndex, this.label}): super._();
  factory _Screen.fromJson(Map<String, dynamic> json) => _$ScreenFromJson(json);

@override final  ScreenId screenId;
@override final  IList<WorkspaceId> workspaceList;
@override final  int selectedIndex;
@override final  String? label;

/// Create a copy of Screen
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScreenCopyWith<_Screen> get copyWith => __$ScreenCopyWithImpl<_Screen>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScreenToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Screen&&(identical(other.screenId, screenId) || other.screenId == screenId)&&const DeepCollectionEquality().equals(other.workspaceList, workspaceList)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,screenId,const DeepCollectionEquality().hash(workspaceList),selectedIndex,label);

@override
String toString() {
  return 'Screen(screenId: $screenId, workspaceList: $workspaceList, selectedIndex: $selectedIndex, label: $label)';
}


}

/// @nodoc
abstract mixin class _$ScreenCopyWith<$Res> implements $ScreenCopyWith<$Res> {
  factory _$ScreenCopyWith(_Screen value, $Res Function(_Screen) _then) = __$ScreenCopyWithImpl;
@override @useResult
$Res call({
 ScreenId screenId, IList<WorkspaceId> workspaceList, int selectedIndex, String? label
});




}
/// @nodoc
class __$ScreenCopyWithImpl<$Res>
    implements _$ScreenCopyWith<$Res> {
  __$ScreenCopyWithImpl(this._self, this._then);

  final _Screen _self;
  final $Res Function(_Screen) _then;

/// Create a copy of Screen
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? screenId = null,Object? workspaceList = null,Object? selectedIndex = null,Object? label = freezed,}) {
  return _then(_Screen(
screenId: null == screenId ? _self.screenId : screenId // ignore: cast_nullable_to_non_nullable
as ScreenId,workspaceList: null == workspaceList ? _self.workspaceList : workspaceList // ignore: cast_nullable_to_non_nullable
as IList<WorkspaceId>,selectedIndex: null == selectedIndex ? _self.selectedIndex : selectedIndex // ignore: cast_nullable_to_non_nullable
as int,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

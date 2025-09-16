// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workspace.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Workspace {

 WorkspaceId get workspaceId; IList<PersistentWindowId> get tileableWindowList; int get selectedIndex; int get visibleLength; WorkspaceCategory? get category; WorkspaceCategory? get forcedCategory;
/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceCopyWith<Workspace> get copyWith => _$WorkspaceCopyWithImpl<Workspace>(this as Workspace, _$identity);

  /// Serializes this Workspace to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Workspace&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&const DeepCollectionEquality().equals(other.tileableWindowList, tileableWindowList)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex)&&(identical(other.visibleLength, visibleLength) || other.visibleLength == visibleLength)&&(identical(other.category, category) || other.category == category)&&(identical(other.forcedCategory, forcedCategory) || other.forcedCategory == forcedCategory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId,const DeepCollectionEquality().hash(tileableWindowList),selectedIndex,visibleLength,category,forcedCategory);

@override
String toString() {
  return 'Workspace(workspaceId: $workspaceId, tileableWindowList: $tileableWindowList, selectedIndex: $selectedIndex, visibleLength: $visibleLength, category: $category, forcedCategory: $forcedCategory)';
}


}

/// @nodoc
abstract mixin class $WorkspaceCopyWith<$Res>  {
  factory $WorkspaceCopyWith(Workspace value, $Res Function(Workspace) _then) = _$WorkspaceCopyWithImpl;
@useResult
$Res call({
 WorkspaceId workspaceId, IList<PersistentWindowId> tileableWindowList, int selectedIndex, int visibleLength, WorkspaceCategory? category, WorkspaceCategory? forcedCategory
});




}
/// @nodoc
class _$WorkspaceCopyWithImpl<$Res>
    implements $WorkspaceCopyWith<$Res> {
  _$WorkspaceCopyWithImpl(this._self, this._then);

  final Workspace _self;
  final $Res Function(Workspace) _then;

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workspaceId = null,Object? tileableWindowList = null,Object? selectedIndex = null,Object? visibleLength = null,Object? category = freezed,Object? forcedCategory = freezed,}) {
  return _then(_self.copyWith(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as WorkspaceId,tileableWindowList: null == tileableWindowList ? _self.tileableWindowList : tileableWindowList // ignore: cast_nullable_to_non_nullable
as IList<PersistentWindowId>,selectedIndex: null == selectedIndex ? _self.selectedIndex : selectedIndex // ignore: cast_nullable_to_non_nullable
as int,visibleLength: null == visibleLength ? _self.visibleLength : visibleLength // ignore: cast_nullable_to_non_nullable
as int,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as WorkspaceCategory?,forcedCategory: freezed == forcedCategory ? _self.forcedCategory : forcedCategory // ignore: cast_nullable_to_non_nullable
as WorkspaceCategory?,
  ));
}

}


/// Adds pattern-matching-related methods to [Workspace].
extension WorkspacePatterns on Workspace {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Workspace value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Workspace() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Workspace value)  $default,){
final _that = this;
switch (_that) {
case _Workspace():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Workspace value)?  $default,){
final _that = this;
switch (_that) {
case _Workspace() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkspaceId workspaceId,  IList<PersistentWindowId> tileableWindowList,  int selectedIndex,  int visibleLength,  WorkspaceCategory? category,  WorkspaceCategory? forcedCategory)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Workspace() when $default != null:
return $default(_that.workspaceId,_that.tileableWindowList,_that.selectedIndex,_that.visibleLength,_that.category,_that.forcedCategory);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkspaceId workspaceId,  IList<PersistentWindowId> tileableWindowList,  int selectedIndex,  int visibleLength,  WorkspaceCategory? category,  WorkspaceCategory? forcedCategory)  $default,) {final _that = this;
switch (_that) {
case _Workspace():
return $default(_that.workspaceId,_that.tileableWindowList,_that.selectedIndex,_that.visibleLength,_that.category,_that.forcedCategory);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkspaceId workspaceId,  IList<PersistentWindowId> tileableWindowList,  int selectedIndex,  int visibleLength,  WorkspaceCategory? category,  WorkspaceCategory? forcedCategory)?  $default,) {final _that = this;
switch (_that) {
case _Workspace() when $default != null:
return $default(_that.workspaceId,_that.tileableWindowList,_that.selectedIndex,_that.visibleLength,_that.category,_that.forcedCategory);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Workspace extends Workspace {
   _Workspace({required this.workspaceId, required this.tileableWindowList, required this.selectedIndex, required this.visibleLength, this.category, this.forcedCategory}): super._();
  factory _Workspace.fromJson(Map<String, dynamic> json) => _$WorkspaceFromJson(json);

@override final  WorkspaceId workspaceId;
@override final  IList<PersistentWindowId> tileableWindowList;
@override final  int selectedIndex;
@override final  int visibleLength;
@override final  WorkspaceCategory? category;
@override final  WorkspaceCategory? forcedCategory;

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceCopyWith<_Workspace> get copyWith => __$WorkspaceCopyWithImpl<_Workspace>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkspaceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Workspace&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&const DeepCollectionEquality().equals(other.tileableWindowList, tileableWindowList)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex)&&(identical(other.visibleLength, visibleLength) || other.visibleLength == visibleLength)&&(identical(other.category, category) || other.category == category)&&(identical(other.forcedCategory, forcedCategory) || other.forcedCategory == forcedCategory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workspaceId,const DeepCollectionEquality().hash(tileableWindowList),selectedIndex,visibleLength,category,forcedCategory);

@override
String toString() {
  return 'Workspace(workspaceId: $workspaceId, tileableWindowList: $tileableWindowList, selectedIndex: $selectedIndex, visibleLength: $visibleLength, category: $category, forcedCategory: $forcedCategory)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceCopyWith<$Res> implements $WorkspaceCopyWith<$Res> {
  factory _$WorkspaceCopyWith(_Workspace value, $Res Function(_Workspace) _then) = __$WorkspaceCopyWithImpl;
@override @useResult
$Res call({
 WorkspaceId workspaceId, IList<PersistentWindowId> tileableWindowList, int selectedIndex, int visibleLength, WorkspaceCategory? category, WorkspaceCategory? forcedCategory
});




}
/// @nodoc
class __$WorkspaceCopyWithImpl<$Res>
    implements _$WorkspaceCopyWith<$Res> {
  __$WorkspaceCopyWithImpl(this._self, this._then);

  final _Workspace _self;
  final $Res Function(_Workspace) _then;

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workspaceId = null,Object? tileableWindowList = null,Object? selectedIndex = null,Object? visibleLength = null,Object? category = freezed,Object? forcedCategory = freezed,}) {
  return _then(_Workspace(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as WorkspaceId,tileableWindowList: null == tileableWindowList ? _self.tileableWindowList : tileableWindowList // ignore: cast_nullable_to_non_nullable
as IList<PersistentWindowId>,selectedIndex: null == selectedIndex ? _self.selectedIndex : selectedIndex // ignore: cast_nullable_to_non_nullable
as int,visibleLength: null == visibleLength ? _self.visibleLength : visibleLength // ignore: cast_nullable_to_non_nullable
as int,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as WorkspaceCategory?,forcedCategory: freezed == forcedCategory ? _self.forcedCategory : forcedCategory // ignore: cast_nullable_to_non_nullable
as WorkspaceCategory?,
  ));
}


}

// dart format on

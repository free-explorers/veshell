// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workspace_drag_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WorkspaceDragData {

 WorkspaceId get workspaceId; ScreenId get screenId;
/// Create a copy of WorkspaceDragData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceDragDataCopyWith<WorkspaceDragData> get copyWith => _$WorkspaceDragDataCopyWithImpl<WorkspaceDragData>(this as WorkspaceDragData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceDragData&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.screenId, screenId) || other.screenId == screenId));
}


@override
int get hashCode => Object.hash(runtimeType,workspaceId,screenId);

@override
String toString() {
  return 'WorkspaceDragData(workspaceId: $workspaceId, screenId: $screenId)';
}


}

/// @nodoc
abstract mixin class $WorkspaceDragDataCopyWith<$Res>  {
  factory $WorkspaceDragDataCopyWith(WorkspaceDragData value, $Res Function(WorkspaceDragData) _then) = _$WorkspaceDragDataCopyWithImpl;
@useResult
$Res call({
 WorkspaceId workspaceId, ScreenId screenId
});




}
/// @nodoc
class _$WorkspaceDragDataCopyWithImpl<$Res>
    implements $WorkspaceDragDataCopyWith<$Res> {
  _$WorkspaceDragDataCopyWithImpl(this._self, this._then);

  final WorkspaceDragData _self;
  final $Res Function(WorkspaceDragData) _then;

/// Create a copy of WorkspaceDragData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workspaceId = null,Object? screenId = null,}) {
  return _then(_self.copyWith(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as WorkspaceId,screenId: null == screenId ? _self.screenId : screenId // ignore: cast_nullable_to_non_nullable
as ScreenId,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceDragData].
extension WorkspaceDragDataPatterns on WorkspaceDragData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceDragData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceDragData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceDragData value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceDragData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceDragData value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceDragData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkspaceId workspaceId,  ScreenId screenId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceDragData() when $default != null:
return $default(_that.workspaceId,_that.screenId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkspaceId workspaceId,  ScreenId screenId)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceDragData():
return $default(_that.workspaceId,_that.screenId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkspaceId workspaceId,  ScreenId screenId)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceDragData() when $default != null:
return $default(_that.workspaceId,_that.screenId);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceDragData implements WorkspaceDragData {
  const _WorkspaceDragData({required this.workspaceId, required this.screenId});
  

@override final  WorkspaceId workspaceId;
@override final  ScreenId screenId;

/// Create a copy of WorkspaceDragData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceDragDataCopyWith<_WorkspaceDragData> get copyWith => __$WorkspaceDragDataCopyWithImpl<_WorkspaceDragData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceDragData&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.screenId, screenId) || other.screenId == screenId));
}


@override
int get hashCode => Object.hash(runtimeType,workspaceId,screenId);

@override
String toString() {
  return 'WorkspaceDragData(workspaceId: $workspaceId, screenId: $screenId)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceDragDataCopyWith<$Res> implements $WorkspaceDragDataCopyWith<$Res> {
  factory _$WorkspaceDragDataCopyWith(_WorkspaceDragData value, $Res Function(_WorkspaceDragData) _then) = __$WorkspaceDragDataCopyWithImpl;
@override @useResult
$Res call({
 WorkspaceId workspaceId, ScreenId screenId
});




}
/// @nodoc
class __$WorkspaceDragDataCopyWithImpl<$Res>
    implements _$WorkspaceDragDataCopyWith<$Res> {
  __$WorkspaceDragDataCopyWithImpl(this._self, this._then);

  final _WorkspaceDragData _self;
  final $Res Function(_WorkspaceDragData) _then;

/// Create a copy of WorkspaceDragData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workspaceId = null,Object? screenId = null,}) {
  return _then(_WorkspaceDragData(
workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as WorkspaceId,screenId: null == screenId ? _self.screenId : screenId // ignore: cast_nullable_to_non_nullable
as ScreenId,
  ));
}


}

// dart format on

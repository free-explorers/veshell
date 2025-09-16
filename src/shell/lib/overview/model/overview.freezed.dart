// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'overview.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Overview {

 ScreenId get screenId; IList<EphemeralWindowId> get windowList; bool get isDisplayed;
/// Create a copy of Overview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OverviewCopyWith<Overview> get copyWith => _$OverviewCopyWithImpl<Overview>(this as Overview, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Overview&&(identical(other.screenId, screenId) || other.screenId == screenId)&&const DeepCollectionEquality().equals(other.windowList, windowList)&&(identical(other.isDisplayed, isDisplayed) || other.isDisplayed == isDisplayed));
}


@override
int get hashCode => Object.hash(runtimeType,screenId,const DeepCollectionEquality().hash(windowList),isDisplayed);

@override
String toString() {
  return 'Overview(screenId: $screenId, windowList: $windowList, isDisplayed: $isDisplayed)';
}


}

/// @nodoc
abstract mixin class $OverviewCopyWith<$Res>  {
  factory $OverviewCopyWith(Overview value, $Res Function(Overview) _then) = _$OverviewCopyWithImpl;
@useResult
$Res call({
 ScreenId screenId, IList<EphemeralWindowId> windowList, bool isDisplayed
});




}
/// @nodoc
class _$OverviewCopyWithImpl<$Res>
    implements $OverviewCopyWith<$Res> {
  _$OverviewCopyWithImpl(this._self, this._then);

  final Overview _self;
  final $Res Function(Overview) _then;

/// Create a copy of Overview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? screenId = null,Object? windowList = null,Object? isDisplayed = null,}) {
  return _then(_self.copyWith(
screenId: null == screenId ? _self.screenId : screenId // ignore: cast_nullable_to_non_nullable
as ScreenId,windowList: null == windowList ? _self.windowList : windowList // ignore: cast_nullable_to_non_nullable
as IList<EphemeralWindowId>,isDisplayed: null == isDisplayed ? _self.isDisplayed : isDisplayed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Overview].
extension OverviewPatterns on Overview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Overview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Overview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Overview value)  $default,){
final _that = this;
switch (_that) {
case _Overview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Overview value)?  $default,){
final _that = this;
switch (_that) {
case _Overview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ScreenId screenId,  IList<EphemeralWindowId> windowList,  bool isDisplayed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Overview() when $default != null:
return $default(_that.screenId,_that.windowList,_that.isDisplayed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ScreenId screenId,  IList<EphemeralWindowId> windowList,  bool isDisplayed)  $default,) {final _that = this;
switch (_that) {
case _Overview():
return $default(_that.screenId,_that.windowList,_that.isDisplayed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ScreenId screenId,  IList<EphemeralWindowId> windowList,  bool isDisplayed)?  $default,) {final _that = this;
switch (_that) {
case _Overview() when $default != null:
return $default(_that.screenId,_that.windowList,_that.isDisplayed);case _:
  return null;

}
}

}

/// @nodoc


class _Overview implements Overview {
   _Overview({required this.screenId, required this.windowList, required this.isDisplayed});
  

@override final  ScreenId screenId;
@override final  IList<EphemeralWindowId> windowList;
@override final  bool isDisplayed;

/// Create a copy of Overview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OverviewCopyWith<_Overview> get copyWith => __$OverviewCopyWithImpl<_Overview>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Overview&&(identical(other.screenId, screenId) || other.screenId == screenId)&&const DeepCollectionEquality().equals(other.windowList, windowList)&&(identical(other.isDisplayed, isDisplayed) || other.isDisplayed == isDisplayed));
}


@override
int get hashCode => Object.hash(runtimeType,screenId,const DeepCollectionEquality().hash(windowList),isDisplayed);

@override
String toString() {
  return 'Overview(screenId: $screenId, windowList: $windowList, isDisplayed: $isDisplayed)';
}


}

/// @nodoc
abstract mixin class _$OverviewCopyWith<$Res> implements $OverviewCopyWith<$Res> {
  factory _$OverviewCopyWith(_Overview value, $Res Function(_Overview) _then) = __$OverviewCopyWithImpl;
@override @useResult
$Res call({
 ScreenId screenId, IList<EphemeralWindowId> windowList, bool isDisplayed
});




}
/// @nodoc
class __$OverviewCopyWithImpl<$Res>
    implements _$OverviewCopyWith<$Res> {
  __$OverviewCopyWithImpl(this._self, this._then);

  final _Overview _self;
  final $Res Function(_Overview) _then;

/// Create a copy of Overview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? screenId = null,Object? windowList = null,Object? isDisplayed = null,}) {
  return _then(_Overview(
screenId: null == screenId ? _self.screenId : screenId // ignore: cast_nullable_to_non_nullable
as ScreenId,windowList: null == windowList ? _self.windowList : windowList // ignore: cast_nullable_to_non_nullable
as IList<EphemeralWindowId>,isDisplayed: null == isDisplayed ? _self.isDisplayed : isDisplayed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

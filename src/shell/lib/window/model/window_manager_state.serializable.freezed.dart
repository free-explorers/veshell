// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'window_manager_state.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WindowManagerState {

 ISet<WindowId> get windows;
/// Create a copy of WindowManagerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WindowManagerStateCopyWith<WindowManagerState> get copyWith => _$WindowManagerStateCopyWithImpl<WindowManagerState>(this as WindowManagerState, _$identity);

  /// Serializes this WindowManagerState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WindowManagerState&&const DeepCollectionEquality().equals(other.windows, windows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(windows));

@override
String toString() {
  return 'WindowManagerState(windows: $windows)';
}


}

/// @nodoc
abstract mixin class $WindowManagerStateCopyWith<$Res>  {
  factory $WindowManagerStateCopyWith(WindowManagerState value, $Res Function(WindowManagerState) _then) = _$WindowManagerStateCopyWithImpl;
@useResult
$Res call({
 ISet<WindowId> windows
});




}
/// @nodoc
class _$WindowManagerStateCopyWithImpl<$Res>
    implements $WindowManagerStateCopyWith<$Res> {
  _$WindowManagerStateCopyWithImpl(this._self, this._then);

  final WindowManagerState _self;
  final $Res Function(WindowManagerState) _then;

/// Create a copy of WindowManagerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? windows = null,}) {
  return _then(_self.copyWith(
windows: null == windows ? _self.windows : windows // ignore: cast_nullable_to_non_nullable
as ISet<WindowId>,
  ));
}

}


/// Adds pattern-matching-related methods to [WindowManagerState].
extension WindowManagerStatePatterns on WindowManagerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WindowManagerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WindowManagerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WindowManagerState value)  $default,){
final _that = this;
switch (_that) {
case _WindowManagerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WindowManagerState value)?  $default,){
final _that = this;
switch (_that) {
case _WindowManagerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ISet<WindowId> windows)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WindowManagerState() when $default != null:
return $default(_that.windows);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ISet<WindowId> windows)  $default,) {final _that = this;
switch (_that) {
case _WindowManagerState():
return $default(_that.windows);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ISet<WindowId> windows)?  $default,) {final _that = this;
switch (_that) {
case _WindowManagerState() when $default != null:
return $default(_that.windows);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WindowManagerState implements WindowManagerState {
  const _WindowManagerState({required this.windows});
  factory _WindowManagerState.fromJson(Map<String, dynamic> json) => _$WindowManagerStateFromJson(json);

@override final  ISet<WindowId> windows;

/// Create a copy of WindowManagerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WindowManagerStateCopyWith<_WindowManagerState> get copyWith => __$WindowManagerStateCopyWithImpl<_WindowManagerState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WindowManagerStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WindowManagerState&&const DeepCollectionEquality().equals(other.windows, windows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(windows));

@override
String toString() {
  return 'WindowManagerState(windows: $windows)';
}


}

/// @nodoc
abstract mixin class _$WindowManagerStateCopyWith<$Res> implements $WindowManagerStateCopyWith<$Res> {
  factory _$WindowManagerStateCopyWith(_WindowManagerState value, $Res Function(_WindowManagerState) _then) = __$WindowManagerStateCopyWithImpl;
@override @useResult
$Res call({
 ISet<WindowId> windows
});




}
/// @nodoc
class __$WindowManagerStateCopyWithImpl<$Res>
    implements _$WindowManagerStateCopyWith<$Res> {
  __$WindowManagerStateCopyWithImpl(this._self, this._then);

  final _WindowManagerState _self;
  final $Res Function(_WindowManagerState) _then;

/// Create a copy of WindowManagerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? windows = null,}) {
  return _then(_WindowManagerState(
windows: null == windows ? _self.windows : windows // ignore: cast_nullable_to_non_nullable
as ISet<WindowId>,
  ));
}


}

// dart format on

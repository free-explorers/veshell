// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cpu.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CpuStats {

 int get cpuLoad; int get loadOnMostUsedCore;
/// Create a copy of CpuStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CpuStatsCopyWith<CpuStats> get copyWith => _$CpuStatsCopyWithImpl<CpuStats>(this as CpuStats, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CpuStats&&(identical(other.cpuLoad, cpuLoad) || other.cpuLoad == cpuLoad)&&(identical(other.loadOnMostUsedCore, loadOnMostUsedCore) || other.loadOnMostUsedCore == loadOnMostUsedCore));
}


@override
int get hashCode => Object.hash(runtimeType,cpuLoad,loadOnMostUsedCore);

@override
String toString() {
  return 'CpuStats(cpuLoad: $cpuLoad, loadOnMostUsedCore: $loadOnMostUsedCore)';
}


}

/// @nodoc
abstract mixin class $CpuStatsCopyWith<$Res>  {
  factory $CpuStatsCopyWith(CpuStats value, $Res Function(CpuStats) _then) = _$CpuStatsCopyWithImpl;
@useResult
$Res call({
 int cpuLoad, int loadOnMostUsedCore
});




}
/// @nodoc
class _$CpuStatsCopyWithImpl<$Res>
    implements $CpuStatsCopyWith<$Res> {
  _$CpuStatsCopyWithImpl(this._self, this._then);

  final CpuStats _self;
  final $Res Function(CpuStats) _then;

/// Create a copy of CpuStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cpuLoad = null,Object? loadOnMostUsedCore = null,}) {
  return _then(_self.copyWith(
cpuLoad: null == cpuLoad ? _self.cpuLoad : cpuLoad // ignore: cast_nullable_to_non_nullable
as int,loadOnMostUsedCore: null == loadOnMostUsedCore ? _self.loadOnMostUsedCore : loadOnMostUsedCore // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CpuStats].
extension CpuStatsPatterns on CpuStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CpuStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CpuStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CpuStats value)  $default,){
final _that = this;
switch (_that) {
case _CpuStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CpuStats value)?  $default,){
final _that = this;
switch (_that) {
case _CpuStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int cpuLoad,  int loadOnMostUsedCore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CpuStats() when $default != null:
return $default(_that.cpuLoad,_that.loadOnMostUsedCore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int cpuLoad,  int loadOnMostUsedCore)  $default,) {final _that = this;
switch (_that) {
case _CpuStats():
return $default(_that.cpuLoad,_that.loadOnMostUsedCore);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int cpuLoad,  int loadOnMostUsedCore)?  $default,) {final _that = this;
switch (_that) {
case _CpuStats() when $default != null:
return $default(_that.cpuLoad,_that.loadOnMostUsedCore);case _:
  return null;

}
}

}

/// @nodoc


class _CpuStats implements CpuStats {
   _CpuStats({required this.cpuLoad, required this.loadOnMostUsedCore});
  

@override final  int cpuLoad;
@override final  int loadOnMostUsedCore;

/// Create a copy of CpuStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CpuStatsCopyWith<_CpuStats> get copyWith => __$CpuStatsCopyWithImpl<_CpuStats>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CpuStats&&(identical(other.cpuLoad, cpuLoad) || other.cpuLoad == cpuLoad)&&(identical(other.loadOnMostUsedCore, loadOnMostUsedCore) || other.loadOnMostUsedCore == loadOnMostUsedCore));
}


@override
int get hashCode => Object.hash(runtimeType,cpuLoad,loadOnMostUsedCore);

@override
String toString() {
  return 'CpuStats(cpuLoad: $cpuLoad, loadOnMostUsedCore: $loadOnMostUsedCore)';
}


}

/// @nodoc
abstract mixin class _$CpuStatsCopyWith<$Res> implements $CpuStatsCopyWith<$Res> {
  factory _$CpuStatsCopyWith(_CpuStats value, $Res Function(_CpuStats) _then) = __$CpuStatsCopyWithImpl;
@override @useResult
$Res call({
 int cpuLoad, int loadOnMostUsedCore
});




}
/// @nodoc
class __$CpuStatsCopyWithImpl<$Res>
    implements _$CpuStatsCopyWith<$Res> {
  __$CpuStatsCopyWithImpl(this._self, this._then);

  final _CpuStats _self;
  final $Res Function(_CpuStats) _then;

/// Create a copy of CpuStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cpuLoad = null,Object? loadOnMostUsedCore = null,}) {
  return _then(_CpuStats(
cpuLoad: null == cpuLoad ? _self.cpuLoad : cpuLoad // ignore: cast_nullable_to_non_nullable
as int,loadOnMostUsedCore: null == loadOnMostUsedCore ? _self.loadOnMostUsedCore : loadOnMostUsedCore // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

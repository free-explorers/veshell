// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'memory.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MemoryStats {

 int get memoryUsage;
/// Create a copy of MemoryStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MemoryStatsCopyWith<MemoryStats> get copyWith => _$MemoryStatsCopyWithImpl<MemoryStats>(this as MemoryStats, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MemoryStats&&(identical(other.memoryUsage, memoryUsage) || other.memoryUsage == memoryUsage));
}


@override
int get hashCode => Object.hash(runtimeType,memoryUsage);

@override
String toString() {
  return 'MemoryStats(memoryUsage: $memoryUsage)';
}


}

/// @nodoc
abstract mixin class $MemoryStatsCopyWith<$Res>  {
  factory $MemoryStatsCopyWith(MemoryStats value, $Res Function(MemoryStats) _then) = _$MemoryStatsCopyWithImpl;
@useResult
$Res call({
 int memoryUsage
});




}
/// @nodoc
class _$MemoryStatsCopyWithImpl<$Res>
    implements $MemoryStatsCopyWith<$Res> {
  _$MemoryStatsCopyWithImpl(this._self, this._then);

  final MemoryStats _self;
  final $Res Function(MemoryStats) _then;

/// Create a copy of MemoryStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? memoryUsage = null,}) {
  return _then(_self.copyWith(
memoryUsage: null == memoryUsage ? _self.memoryUsage : memoryUsage // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MemoryStats].
extension MemoryStatsPatterns on MemoryStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MemoryStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MemoryStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MemoryStats value)  $default,){
final _that = this;
switch (_that) {
case _MemoryStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MemoryStats value)?  $default,){
final _that = this;
switch (_that) {
case _MemoryStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int memoryUsage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MemoryStats() when $default != null:
return $default(_that.memoryUsage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int memoryUsage)  $default,) {final _that = this;
switch (_that) {
case _MemoryStats():
return $default(_that.memoryUsage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int memoryUsage)?  $default,) {final _that = this;
switch (_that) {
case _MemoryStats() when $default != null:
return $default(_that.memoryUsage);case _:
  return null;

}
}

}

/// @nodoc


class _MemoryStats implements MemoryStats {
   _MemoryStats({required this.memoryUsage});
  

@override final  int memoryUsage;

/// Create a copy of MemoryStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MemoryStatsCopyWith<_MemoryStats> get copyWith => __$MemoryStatsCopyWithImpl<_MemoryStats>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MemoryStats&&(identical(other.memoryUsage, memoryUsage) || other.memoryUsage == memoryUsage));
}


@override
int get hashCode => Object.hash(runtimeType,memoryUsage);

@override
String toString() {
  return 'MemoryStats(memoryUsage: $memoryUsage)';
}


}

/// @nodoc
abstract mixin class _$MemoryStatsCopyWith<$Res> implements $MemoryStatsCopyWith<$Res> {
  factory _$MemoryStatsCopyWith(_MemoryStats value, $Res Function(_MemoryStats) _then) = __$MemoryStatsCopyWithImpl;
@override @useResult
$Res call({
 int memoryUsage
});




}
/// @nodoc
class __$MemoryStatsCopyWithImpl<$Res>
    implements _$MemoryStatsCopyWith<$Res> {
  __$MemoryStatsCopyWithImpl(this._self, this._then);

  final _MemoryStats _self;
  final $Res Function(_MemoryStats) _then;

/// Create a copy of MemoryStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? memoryUsage = null,}) {
  return _then(_MemoryStats(
memoryUsage: null == memoryUsage ? _self.memoryUsage : memoryUsage // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

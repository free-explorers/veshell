// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'memory_stats_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MemoryStatsSnapshot {

 int get totalMem; int get freeMem; IMap<int, int> get memoryUsagePerProcess;
/// Create a copy of MemoryStatsSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MemoryStatsSnapshotCopyWith<MemoryStatsSnapshot> get copyWith => _$MemoryStatsSnapshotCopyWithImpl<MemoryStatsSnapshot>(this as MemoryStatsSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MemoryStatsSnapshot&&(identical(other.totalMem, totalMem) || other.totalMem == totalMem)&&(identical(other.freeMem, freeMem) || other.freeMem == freeMem)&&(identical(other.memoryUsagePerProcess, memoryUsagePerProcess) || other.memoryUsagePerProcess == memoryUsagePerProcess));
}


@override
int get hashCode => Object.hash(runtimeType,totalMem,freeMem,memoryUsagePerProcess);

@override
String toString() {
  return 'MemoryStatsSnapshot(totalMem: $totalMem, freeMem: $freeMem, memoryUsagePerProcess: $memoryUsagePerProcess)';
}


}

/// @nodoc
abstract mixin class $MemoryStatsSnapshotCopyWith<$Res>  {
  factory $MemoryStatsSnapshotCopyWith(MemoryStatsSnapshot value, $Res Function(MemoryStatsSnapshot) _then) = _$MemoryStatsSnapshotCopyWithImpl;
@useResult
$Res call({
 int totalMem, int freeMem, IMap<int, int> memoryUsagePerProcess
});




}
/// @nodoc
class _$MemoryStatsSnapshotCopyWithImpl<$Res>
    implements $MemoryStatsSnapshotCopyWith<$Res> {
  _$MemoryStatsSnapshotCopyWithImpl(this._self, this._then);

  final MemoryStatsSnapshot _self;
  final $Res Function(MemoryStatsSnapshot) _then;

/// Create a copy of MemoryStatsSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalMem = null,Object? freeMem = null,Object? memoryUsagePerProcess = null,}) {
  return _then(_self.copyWith(
totalMem: null == totalMem ? _self.totalMem : totalMem // ignore: cast_nullable_to_non_nullable
as int,freeMem: null == freeMem ? _self.freeMem : freeMem // ignore: cast_nullable_to_non_nullable
as int,memoryUsagePerProcess: null == memoryUsagePerProcess ? _self.memoryUsagePerProcess : memoryUsagePerProcess // ignore: cast_nullable_to_non_nullable
as IMap<int, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [MemoryStatsSnapshot].
extension MemoryStatsSnapshotPatterns on MemoryStatsSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MemoryStatsSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MemoryStatsSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MemoryStatsSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _MemoryStatsSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MemoryStatsSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _MemoryStatsSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalMem,  int freeMem,  IMap<int, int> memoryUsagePerProcess)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MemoryStatsSnapshot() when $default != null:
return $default(_that.totalMem,_that.freeMem,_that.memoryUsagePerProcess);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalMem,  int freeMem,  IMap<int, int> memoryUsagePerProcess)  $default,) {final _that = this;
switch (_that) {
case _MemoryStatsSnapshot():
return $default(_that.totalMem,_that.freeMem,_that.memoryUsagePerProcess);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalMem,  int freeMem,  IMap<int, int> memoryUsagePerProcess)?  $default,) {final _that = this;
switch (_that) {
case _MemoryStatsSnapshot() when $default != null:
return $default(_that.totalMem,_that.freeMem,_that.memoryUsagePerProcess);case _:
  return null;

}
}

}

/// @nodoc


class _MemoryStatsSnapshot implements MemoryStatsSnapshot {
   _MemoryStatsSnapshot({required this.totalMem, required this.freeMem, required this.memoryUsagePerProcess});
  

@override final  int totalMem;
@override final  int freeMem;
@override final  IMap<int, int> memoryUsagePerProcess;

/// Create a copy of MemoryStatsSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MemoryStatsSnapshotCopyWith<_MemoryStatsSnapshot> get copyWith => __$MemoryStatsSnapshotCopyWithImpl<_MemoryStatsSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MemoryStatsSnapshot&&(identical(other.totalMem, totalMem) || other.totalMem == totalMem)&&(identical(other.freeMem, freeMem) || other.freeMem == freeMem)&&(identical(other.memoryUsagePerProcess, memoryUsagePerProcess) || other.memoryUsagePerProcess == memoryUsagePerProcess));
}


@override
int get hashCode => Object.hash(runtimeType,totalMem,freeMem,memoryUsagePerProcess);

@override
String toString() {
  return 'MemoryStatsSnapshot(totalMem: $totalMem, freeMem: $freeMem, memoryUsagePerProcess: $memoryUsagePerProcess)';
}


}

/// @nodoc
abstract mixin class _$MemoryStatsSnapshotCopyWith<$Res> implements $MemoryStatsSnapshotCopyWith<$Res> {
  factory _$MemoryStatsSnapshotCopyWith(_MemoryStatsSnapshot value, $Res Function(_MemoryStatsSnapshot) _then) = __$MemoryStatsSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int totalMem, int freeMem, IMap<int, int> memoryUsagePerProcess
});




}
/// @nodoc
class __$MemoryStatsSnapshotCopyWithImpl<$Res>
    implements _$MemoryStatsSnapshotCopyWith<$Res> {
  __$MemoryStatsSnapshotCopyWithImpl(this._self, this._then);

  final _MemoryStatsSnapshot _self;
  final $Res Function(_MemoryStatsSnapshot) _then;

/// Create a copy of MemoryStatsSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalMem = null,Object? freeMem = null,Object? memoryUsagePerProcess = null,}) {
  return _then(_MemoryStatsSnapshot(
totalMem: null == totalMem ? _self.totalMem : totalMem // ignore: cast_nullable_to_non_nullable
as int,freeMem: null == freeMem ? _self.freeMem : freeMem // ignore: cast_nullable_to_non_nullable
as int,memoryUsagePerProcess: null == memoryUsagePerProcess ? _self.memoryUsagePerProcess : memoryUsagePerProcess // ignore: cast_nullable_to_non_nullable
as IMap<int, int>,
  ));
}


}

// dart format on

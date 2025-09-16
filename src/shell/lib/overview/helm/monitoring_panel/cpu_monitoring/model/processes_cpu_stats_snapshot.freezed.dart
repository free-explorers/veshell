// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'processes_cpu_stats_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProcessesCpuStatsSnapshot {

 int get totalCpu; IMap<int, int> get cpuUsagePerProcess;
/// Create a copy of ProcessesCpuStatsSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProcessesCpuStatsSnapshotCopyWith<ProcessesCpuStatsSnapshot> get copyWith => _$ProcessesCpuStatsSnapshotCopyWithImpl<ProcessesCpuStatsSnapshot>(this as ProcessesCpuStatsSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProcessesCpuStatsSnapshot&&(identical(other.totalCpu, totalCpu) || other.totalCpu == totalCpu)&&(identical(other.cpuUsagePerProcess, cpuUsagePerProcess) || other.cpuUsagePerProcess == cpuUsagePerProcess));
}


@override
int get hashCode => Object.hash(runtimeType,totalCpu,cpuUsagePerProcess);

@override
String toString() {
  return 'ProcessesCpuStatsSnapshot(totalCpu: $totalCpu, cpuUsagePerProcess: $cpuUsagePerProcess)';
}


}

/// @nodoc
abstract mixin class $ProcessesCpuStatsSnapshotCopyWith<$Res>  {
  factory $ProcessesCpuStatsSnapshotCopyWith(ProcessesCpuStatsSnapshot value, $Res Function(ProcessesCpuStatsSnapshot) _then) = _$ProcessesCpuStatsSnapshotCopyWithImpl;
@useResult
$Res call({
 int totalCpu, IMap<int, int> cpuUsagePerProcess
});




}
/// @nodoc
class _$ProcessesCpuStatsSnapshotCopyWithImpl<$Res>
    implements $ProcessesCpuStatsSnapshotCopyWith<$Res> {
  _$ProcessesCpuStatsSnapshotCopyWithImpl(this._self, this._then);

  final ProcessesCpuStatsSnapshot _self;
  final $Res Function(ProcessesCpuStatsSnapshot) _then;

/// Create a copy of ProcessesCpuStatsSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalCpu = null,Object? cpuUsagePerProcess = null,}) {
  return _then(_self.copyWith(
totalCpu: null == totalCpu ? _self.totalCpu : totalCpu // ignore: cast_nullable_to_non_nullable
as int,cpuUsagePerProcess: null == cpuUsagePerProcess ? _self.cpuUsagePerProcess : cpuUsagePerProcess // ignore: cast_nullable_to_non_nullable
as IMap<int, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProcessesCpuStatsSnapshot].
extension ProcessesCpuStatsSnapshotPatterns on ProcessesCpuStatsSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProcessesCpuStatsSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProcessesCpuStatsSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProcessesCpuStatsSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _ProcessesCpuStatsSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProcessesCpuStatsSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _ProcessesCpuStatsSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalCpu,  IMap<int, int> cpuUsagePerProcess)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProcessesCpuStatsSnapshot() when $default != null:
return $default(_that.totalCpu,_that.cpuUsagePerProcess);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalCpu,  IMap<int, int> cpuUsagePerProcess)  $default,) {final _that = this;
switch (_that) {
case _ProcessesCpuStatsSnapshot():
return $default(_that.totalCpu,_that.cpuUsagePerProcess);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalCpu,  IMap<int, int> cpuUsagePerProcess)?  $default,) {final _that = this;
switch (_that) {
case _ProcessesCpuStatsSnapshot() when $default != null:
return $default(_that.totalCpu,_that.cpuUsagePerProcess);case _:
  return null;

}
}

}

/// @nodoc


class _ProcessesCpuStatsSnapshot implements ProcessesCpuStatsSnapshot {
   _ProcessesCpuStatsSnapshot({required this.totalCpu, required this.cpuUsagePerProcess});
  

@override final  int totalCpu;
@override final  IMap<int, int> cpuUsagePerProcess;

/// Create a copy of ProcessesCpuStatsSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProcessesCpuStatsSnapshotCopyWith<_ProcessesCpuStatsSnapshot> get copyWith => __$ProcessesCpuStatsSnapshotCopyWithImpl<_ProcessesCpuStatsSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProcessesCpuStatsSnapshot&&(identical(other.totalCpu, totalCpu) || other.totalCpu == totalCpu)&&(identical(other.cpuUsagePerProcess, cpuUsagePerProcess) || other.cpuUsagePerProcess == cpuUsagePerProcess));
}


@override
int get hashCode => Object.hash(runtimeType,totalCpu,cpuUsagePerProcess);

@override
String toString() {
  return 'ProcessesCpuStatsSnapshot(totalCpu: $totalCpu, cpuUsagePerProcess: $cpuUsagePerProcess)';
}


}

/// @nodoc
abstract mixin class _$ProcessesCpuStatsSnapshotCopyWith<$Res> implements $ProcessesCpuStatsSnapshotCopyWith<$Res> {
  factory _$ProcessesCpuStatsSnapshotCopyWith(_ProcessesCpuStatsSnapshot value, $Res Function(_ProcessesCpuStatsSnapshot) _then) = __$ProcessesCpuStatsSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int totalCpu, IMap<int, int> cpuUsagePerProcess
});




}
/// @nodoc
class __$ProcessesCpuStatsSnapshotCopyWithImpl<$Res>
    implements _$ProcessesCpuStatsSnapshotCopyWith<$Res> {
  __$ProcessesCpuStatsSnapshotCopyWithImpl(this._self, this._then);

  final _ProcessesCpuStatsSnapshot _self;
  final $Res Function(_ProcessesCpuStatsSnapshot) _then;

/// Create a copy of ProcessesCpuStatsSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalCpu = null,Object? cpuUsagePerProcess = null,}) {
  return _then(_ProcessesCpuStatsSnapshot(
totalCpu: null == totalCpu ? _self.totalCpu : totalCpu // ignore: cast_nullable_to_non_nullable
as int,cpuUsagePerProcess: null == cpuUsagePerProcess ? _self.cpuUsagePerProcess : cpuUsagePerProcess // ignore: cast_nullable_to_non_nullable
as IMap<int, int>,
  ));
}


}

// dart format on

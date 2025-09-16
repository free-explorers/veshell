// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'process_stat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProcessStat {

 int get pid; String get name; int get cpuUsage; int get memoryUsage; int get networkUsage;
/// Create a copy of ProcessStat
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProcessStatCopyWith<ProcessStat> get copyWith => _$ProcessStatCopyWithImpl<ProcessStat>(this as ProcessStat, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProcessStat&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.name, name) || other.name == name)&&(identical(other.cpuUsage, cpuUsage) || other.cpuUsage == cpuUsage)&&(identical(other.memoryUsage, memoryUsage) || other.memoryUsage == memoryUsage)&&(identical(other.networkUsage, networkUsage) || other.networkUsage == networkUsage));
}


@override
int get hashCode => Object.hash(runtimeType,pid,name,cpuUsage,memoryUsage,networkUsage);

@override
String toString() {
  return 'ProcessStat(pid: $pid, name: $name, cpuUsage: $cpuUsage, memoryUsage: $memoryUsage, networkUsage: $networkUsage)';
}


}

/// @nodoc
abstract mixin class $ProcessStatCopyWith<$Res>  {
  factory $ProcessStatCopyWith(ProcessStat value, $Res Function(ProcessStat) _then) = _$ProcessStatCopyWithImpl;
@useResult
$Res call({
 int pid, String name, int cpuUsage, int memoryUsage, int networkUsage
});




}
/// @nodoc
class _$ProcessStatCopyWithImpl<$Res>
    implements $ProcessStatCopyWith<$Res> {
  _$ProcessStatCopyWithImpl(this._self, this._then);

  final ProcessStat _self;
  final $Res Function(ProcessStat) _then;

/// Create a copy of ProcessStat
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pid = null,Object? name = null,Object? cpuUsage = null,Object? memoryUsage = null,Object? networkUsage = null,}) {
  return _then(_self.copyWith(
pid: null == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cpuUsage: null == cpuUsage ? _self.cpuUsage : cpuUsage // ignore: cast_nullable_to_non_nullable
as int,memoryUsage: null == memoryUsage ? _self.memoryUsage : memoryUsage // ignore: cast_nullable_to_non_nullable
as int,networkUsage: null == networkUsage ? _self.networkUsage : networkUsage // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ProcessStat].
extension ProcessStatPatterns on ProcessStat {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProcessStat value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProcessStat() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProcessStat value)  $default,){
final _that = this;
switch (_that) {
case _ProcessStat():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProcessStat value)?  $default,){
final _that = this;
switch (_that) {
case _ProcessStat() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int pid,  String name,  int cpuUsage,  int memoryUsage,  int networkUsage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProcessStat() when $default != null:
return $default(_that.pid,_that.name,_that.cpuUsage,_that.memoryUsage,_that.networkUsage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int pid,  String name,  int cpuUsage,  int memoryUsage,  int networkUsage)  $default,) {final _that = this;
switch (_that) {
case _ProcessStat():
return $default(_that.pid,_that.name,_that.cpuUsage,_that.memoryUsage,_that.networkUsage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int pid,  String name,  int cpuUsage,  int memoryUsage,  int networkUsage)?  $default,) {final _that = this;
switch (_that) {
case _ProcessStat() when $default != null:
return $default(_that.pid,_that.name,_that.cpuUsage,_that.memoryUsage,_that.networkUsage);case _:
  return null;

}
}

}

/// @nodoc


class _ProcessStat implements ProcessStat {
   _ProcessStat({required this.pid, required this.name, required this.cpuUsage, required this.memoryUsage, required this.networkUsage});
  

@override final  int pid;
@override final  String name;
@override final  int cpuUsage;
@override final  int memoryUsage;
@override final  int networkUsage;

/// Create a copy of ProcessStat
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProcessStatCopyWith<_ProcessStat> get copyWith => __$ProcessStatCopyWithImpl<_ProcessStat>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProcessStat&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.name, name) || other.name == name)&&(identical(other.cpuUsage, cpuUsage) || other.cpuUsage == cpuUsage)&&(identical(other.memoryUsage, memoryUsage) || other.memoryUsage == memoryUsage)&&(identical(other.networkUsage, networkUsage) || other.networkUsage == networkUsage));
}


@override
int get hashCode => Object.hash(runtimeType,pid,name,cpuUsage,memoryUsage,networkUsage);

@override
String toString() {
  return 'ProcessStat(pid: $pid, name: $name, cpuUsage: $cpuUsage, memoryUsage: $memoryUsage, networkUsage: $networkUsage)';
}


}

/// @nodoc
abstract mixin class _$ProcessStatCopyWith<$Res> implements $ProcessStatCopyWith<$Res> {
  factory _$ProcessStatCopyWith(_ProcessStat value, $Res Function(_ProcessStat) _then) = __$ProcessStatCopyWithImpl;
@override @useResult
$Res call({
 int pid, String name, int cpuUsage, int memoryUsage, int networkUsage
});




}
/// @nodoc
class __$ProcessStatCopyWithImpl<$Res>
    implements _$ProcessStatCopyWith<$Res> {
  __$ProcessStatCopyWithImpl(this._self, this._then);

  final _ProcessStat _self;
  final $Res Function(_ProcessStat) _then;

/// Create a copy of ProcessStat
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pid = null,Object? name = null,Object? cpuUsage = null,Object? memoryUsage = null,Object? networkUsage = null,}) {
  return _then(_ProcessStat(
pid: null == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cpuUsage: null == cpuUsage ? _self.cpuUsage : cpuUsage // ignore: cast_nullable_to_non_nullable
as int,memoryUsage: null == memoryUsage ? _self.memoryUsage : memoryUsage // ignore: cast_nullable_to_non_nullable
as int,networkUsage: null == networkUsage ? _self.networkUsage : networkUsage // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

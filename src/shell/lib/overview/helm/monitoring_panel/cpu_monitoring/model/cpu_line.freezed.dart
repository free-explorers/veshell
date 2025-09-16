// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cpu_line.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CpuLine {

 String get label; int get user; int get nice; int get system; int get idle; int get iowait; int get irq; int get softirq; int get steal; int get guest; int get guestNice;
/// Create a copy of CpuLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CpuLineCopyWith<CpuLine> get copyWith => _$CpuLineCopyWithImpl<CpuLine>(this as CpuLine, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CpuLine&&(identical(other.label, label) || other.label == label)&&(identical(other.user, user) || other.user == user)&&(identical(other.nice, nice) || other.nice == nice)&&(identical(other.system, system) || other.system == system)&&(identical(other.idle, idle) || other.idle == idle)&&(identical(other.iowait, iowait) || other.iowait == iowait)&&(identical(other.irq, irq) || other.irq == irq)&&(identical(other.softirq, softirq) || other.softirq == softirq)&&(identical(other.steal, steal) || other.steal == steal)&&(identical(other.guest, guest) || other.guest == guest)&&(identical(other.guestNice, guestNice) || other.guestNice == guestNice));
}


@override
int get hashCode => Object.hash(runtimeType,label,user,nice,system,idle,iowait,irq,softirq,steal,guest,guestNice);

@override
String toString() {
  return 'CpuLine(label: $label, user: $user, nice: $nice, system: $system, idle: $idle, iowait: $iowait, irq: $irq, softirq: $softirq, steal: $steal, guest: $guest, guestNice: $guestNice)';
}


}

/// @nodoc
abstract mixin class $CpuLineCopyWith<$Res>  {
  factory $CpuLineCopyWith(CpuLine value, $Res Function(CpuLine) _then) = _$CpuLineCopyWithImpl;
@useResult
$Res call({
 String label, int user, int nice, int system, int idle, int iowait, int irq, int softirq, int steal, int guest, int guestNice
});




}
/// @nodoc
class _$CpuLineCopyWithImpl<$Res>
    implements $CpuLineCopyWith<$Res> {
  _$CpuLineCopyWithImpl(this._self, this._then);

  final CpuLine _self;
  final $Res Function(CpuLine) _then;

/// Create a copy of CpuLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? user = null,Object? nice = null,Object? system = null,Object? idle = null,Object? iowait = null,Object? irq = null,Object? softirq = null,Object? steal = null,Object? guest = null,Object? guestNice = null,}) {
  return _then(_self.copyWith(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as int,nice: null == nice ? _self.nice : nice // ignore: cast_nullable_to_non_nullable
as int,system: null == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as int,idle: null == idle ? _self.idle : idle // ignore: cast_nullable_to_non_nullable
as int,iowait: null == iowait ? _self.iowait : iowait // ignore: cast_nullable_to_non_nullable
as int,irq: null == irq ? _self.irq : irq // ignore: cast_nullable_to_non_nullable
as int,softirq: null == softirq ? _self.softirq : softirq // ignore: cast_nullable_to_non_nullable
as int,steal: null == steal ? _self.steal : steal // ignore: cast_nullable_to_non_nullable
as int,guest: null == guest ? _self.guest : guest // ignore: cast_nullable_to_non_nullable
as int,guestNice: null == guestNice ? _self.guestNice : guestNice // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CpuLine].
extension CpuLinePatterns on CpuLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CpuLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CpuLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CpuLine value)  $default,){
final _that = this;
switch (_that) {
case _CpuLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CpuLine value)?  $default,){
final _that = this;
switch (_that) {
case _CpuLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  int user,  int nice,  int system,  int idle,  int iowait,  int irq,  int softirq,  int steal,  int guest,  int guestNice)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CpuLine() when $default != null:
return $default(_that.label,_that.user,_that.nice,_that.system,_that.idle,_that.iowait,_that.irq,_that.softirq,_that.steal,_that.guest,_that.guestNice);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  int user,  int nice,  int system,  int idle,  int iowait,  int irq,  int softirq,  int steal,  int guest,  int guestNice)  $default,) {final _that = this;
switch (_that) {
case _CpuLine():
return $default(_that.label,_that.user,_that.nice,_that.system,_that.idle,_that.iowait,_that.irq,_that.softirq,_that.steal,_that.guest,_that.guestNice);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  int user,  int nice,  int system,  int idle,  int iowait,  int irq,  int softirq,  int steal,  int guest,  int guestNice)?  $default,) {final _that = this;
switch (_that) {
case _CpuLine() when $default != null:
return $default(_that.label,_that.user,_that.nice,_that.system,_that.idle,_that.iowait,_that.irq,_that.softirq,_that.steal,_that.guest,_that.guestNice);case _:
  return null;

}
}

}

/// @nodoc


class _CpuLine implements CpuLine {
   _CpuLine({required this.label, required this.user, required this.nice, required this.system, required this.idle, required this.iowait, required this.irq, required this.softirq, required this.steal, required this.guest, required this.guestNice});
  

@override final  String label;
@override final  int user;
@override final  int nice;
@override final  int system;
@override final  int idle;
@override final  int iowait;
@override final  int irq;
@override final  int softirq;
@override final  int steal;
@override final  int guest;
@override final  int guestNice;

/// Create a copy of CpuLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CpuLineCopyWith<_CpuLine> get copyWith => __$CpuLineCopyWithImpl<_CpuLine>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CpuLine&&(identical(other.label, label) || other.label == label)&&(identical(other.user, user) || other.user == user)&&(identical(other.nice, nice) || other.nice == nice)&&(identical(other.system, system) || other.system == system)&&(identical(other.idle, idle) || other.idle == idle)&&(identical(other.iowait, iowait) || other.iowait == iowait)&&(identical(other.irq, irq) || other.irq == irq)&&(identical(other.softirq, softirq) || other.softirq == softirq)&&(identical(other.steal, steal) || other.steal == steal)&&(identical(other.guest, guest) || other.guest == guest)&&(identical(other.guestNice, guestNice) || other.guestNice == guestNice));
}


@override
int get hashCode => Object.hash(runtimeType,label,user,nice,system,idle,iowait,irq,softirq,steal,guest,guestNice);

@override
String toString() {
  return 'CpuLine(label: $label, user: $user, nice: $nice, system: $system, idle: $idle, iowait: $iowait, irq: $irq, softirq: $softirq, steal: $steal, guest: $guest, guestNice: $guestNice)';
}


}

/// @nodoc
abstract mixin class _$CpuLineCopyWith<$Res> implements $CpuLineCopyWith<$Res> {
  factory _$CpuLineCopyWith(_CpuLine value, $Res Function(_CpuLine) _then) = __$CpuLineCopyWithImpl;
@override @useResult
$Res call({
 String label, int user, int nice, int system, int idle, int iowait, int irq, int softirq, int steal, int guest, int guestNice
});




}
/// @nodoc
class __$CpuLineCopyWithImpl<$Res>
    implements _$CpuLineCopyWith<$Res> {
  __$CpuLineCopyWithImpl(this._self, this._then);

  final _CpuLine _self;
  final $Res Function(_CpuLine) _then;

/// Create a copy of CpuLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? user = null,Object? nice = null,Object? system = null,Object? idle = null,Object? iowait = null,Object? irq = null,Object? softirq = null,Object? steal = null,Object? guest = null,Object? guestNice = null,}) {
  return _then(_CpuLine(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as int,nice: null == nice ? _self.nice : nice // ignore: cast_nullable_to_non_nullable
as int,system: null == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as int,idle: null == idle ? _self.idle : idle // ignore: cast_nullable_to_non_nullable
as int,iowait: null == iowait ? _self.iowait : iowait // ignore: cast_nullable_to_non_nullable
as int,irq: null == irq ? _self.irq : irq // ignore: cast_nullable_to_non_nullable
as int,softirq: null == softirq ? _self.softirq : softirq // ignore: cast_nullable_to_non_nullable
as int,steal: null == steal ? _self.steal : steal // ignore: cast_nullable_to_non_nullable
as int,guest: null == guest ? _self.guest : guest // ignore: cast_nullable_to_non_nullable
as int,guestNice: null == guestNice ? _self.guestNice : guestNice // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

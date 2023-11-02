// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../util/state/lock_screen_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$LockScreenState {
  bool get locked => throw _privateConstructorUsedError;
  Object get lock => throw _privateConstructorUsedError;
  Object get unlock => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $LockScreenStateCopyWith<LockScreenState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LockScreenStateCopyWith<$Res> {
  factory $LockScreenStateCopyWith(
          LockScreenState value, $Res Function(LockScreenState) then) =
      _$LockScreenStateCopyWithImpl<$Res, LockScreenState>;
  @useResult
  $Res call({bool locked, Object lock, Object unlock});
}

/// @nodoc
class _$LockScreenStateCopyWithImpl<$Res, $Val extends LockScreenState>
    implements $LockScreenStateCopyWith<$Res> {
  _$LockScreenStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? locked = null,
    Object? lock = null,
    Object? unlock = null,
  }) {
    return _then(_value.copyWith(
      locked: null == locked
          ? _value.locked
          : locked // ignore: cast_nullable_to_non_nullable
              as bool,
      lock: null == lock ? _value.lock : lock,
      unlock: null == unlock ? _value.unlock : unlock,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_LockScreenStateCopyWith<$Res>
    implements $LockScreenStateCopyWith<$Res> {
  factory _$$_LockScreenStateCopyWith(
          _$_LockScreenState value, $Res Function(_$_LockScreenState) then) =
      __$$_LockScreenStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool locked, Object lock, Object unlock});
}

/// @nodoc
class __$$_LockScreenStateCopyWithImpl<$Res>
    extends _$LockScreenStateCopyWithImpl<$Res, _$_LockScreenState>
    implements _$$_LockScreenStateCopyWith<$Res> {
  __$$_LockScreenStateCopyWithImpl(
      _$_LockScreenState _value, $Res Function(_$_LockScreenState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? locked = null,
    Object? lock = null,
    Object? unlock = null,
  }) {
    return _then(_$_LockScreenState(
      locked: null == locked
          ? _value.locked
          : locked // ignore: cast_nullable_to_non_nullable
              as bool,
      lock: null == lock ? _value.lock : lock,
      unlock: null == unlock ? _value.unlock : unlock,
    ));
  }
}

/// @nodoc

class _$_LockScreenState implements _LockScreenState {
  const _$_LockScreenState(
      {required this.locked, required this.lock, required this.unlock});

  @override
  final bool locked;
  @override
  final Object lock;
  @override
  final Object unlock;

  @override
  String toString() {
    return 'LockScreenState(locked: $locked, lock: $lock, unlock: $unlock)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_LockScreenState &&
            (identical(other.locked, locked) || other.locked == locked) &&
            const DeepCollectionEquality().equals(other.lock, lock) &&
            const DeepCollectionEquality().equals(other.unlock, unlock));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      locked,
      const DeepCollectionEquality().hash(lock),
      const DeepCollectionEquality().hash(unlock));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_LockScreenStateCopyWith<_$_LockScreenState> get copyWith =>
      __$$_LockScreenStateCopyWithImpl<_$_LockScreenState>(this, _$identity);
}

abstract class _LockScreenState implements LockScreenState {
  const factory _LockScreenState(
      {required final bool locked,
      required final Object lock,
      required final Object unlock}) = _$_LockScreenState;

  @override
  bool get locked;
  @override
  Object get lock;
  @override
  Object get unlock;
  @override
  @JsonKey(ignore: true)
  _$$_LockScreenStateCopyWith<_$_LockScreenState> get copyWith =>
      throw _privateConstructorUsedError;
}

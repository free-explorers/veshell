// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../util/state/screen_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$ScreenState {
  bool get on => throw _privateConstructorUsedError;

  /// Turn on/off operations have not yet finished.
  bool get pending => throw _privateConstructorUsedError;

  /// Rotation expressed in clockwise quarter turns.
  int get rotation => throw _privateConstructorUsedError;

  /// The screen size, before rotation.
  Size get size => throw _privateConstructorUsedError;

  /// The screen size, after rotation.
  /// If the physical screen is 500x1000 in portrait and the device is rotated in landscape, this
  /// variable contains the size 1000x500.
  Size get rotatedSize => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ScreenStateCopyWith<ScreenState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScreenStateCopyWith<$Res> {
  factory $ScreenStateCopyWith(
          ScreenState value, $Res Function(ScreenState) then) =
      _$ScreenStateCopyWithImpl<$Res, ScreenState>;
  @useResult
  $Res call({bool on, bool pending, int rotation, Size size, Size rotatedSize});
}

/// @nodoc
class _$ScreenStateCopyWithImpl<$Res, $Val extends ScreenState>
    implements $ScreenStateCopyWith<$Res> {
  _$ScreenStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? on = null,
    Object? pending = null,
    Object? rotation = null,
    Object? size = null,
    Object? rotatedSize = null,
  }) {
    return _then(_value.copyWith(
      on: null == on
          ? _value.on
          : on // ignore: cast_nullable_to_non_nullable
              as bool,
      pending: null == pending
          ? _value.pending
          : pending // ignore: cast_nullable_to_non_nullable
              as bool,
      rotation: null == rotation
          ? _value.rotation
          : rotation // ignore: cast_nullable_to_non_nullable
              as int,
      size: null == size
          ? _value.size
          : size // ignore: cast_nullable_to_non_nullable
              as Size,
      rotatedSize: null == rotatedSize
          ? _value.rotatedSize
          : rotatedSize // ignore: cast_nullable_to_non_nullable
              as Size,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_ScreenStateCopyWith<$Res>
    implements $ScreenStateCopyWith<$Res> {
  factory _$$_ScreenStateCopyWith(
          _$_ScreenState value, $Res Function(_$_ScreenState) then) =
      __$$_ScreenStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool on, bool pending, int rotation, Size size, Size rotatedSize});
}

/// @nodoc
class __$$_ScreenStateCopyWithImpl<$Res>
    extends _$ScreenStateCopyWithImpl<$Res, _$_ScreenState>
    implements _$$_ScreenStateCopyWith<$Res> {
  __$$_ScreenStateCopyWithImpl(
      _$_ScreenState _value, $Res Function(_$_ScreenState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? on = null,
    Object? pending = null,
    Object? rotation = null,
    Object? size = null,
    Object? rotatedSize = null,
  }) {
    return _then(_$_ScreenState(
      on: null == on
          ? _value.on
          : on // ignore: cast_nullable_to_non_nullable
              as bool,
      pending: null == pending
          ? _value.pending
          : pending // ignore: cast_nullable_to_non_nullable
              as bool,
      rotation: null == rotation
          ? _value.rotation
          : rotation // ignore: cast_nullable_to_non_nullable
              as int,
      size: null == size
          ? _value.size
          : size // ignore: cast_nullable_to_non_nullable
              as Size,
      rotatedSize: null == rotatedSize
          ? _value.rotatedSize
          : rotatedSize // ignore: cast_nullable_to_non_nullable
              as Size,
    ));
  }
}

/// @nodoc

class _$_ScreenState implements _ScreenState {
  const _$_ScreenState(
      {required this.on,
      required this.pending,
      required this.rotation,
      required this.size,
      required this.rotatedSize});

  @override
  final bool on;

  /// Turn on/off operations have not yet finished.
  @override
  final bool pending;

  /// Rotation expressed in clockwise quarter turns.
  @override
  final int rotation;

  /// The screen size, before rotation.
  @override
  final Size size;

  /// The screen size, after rotation.
  /// If the physical screen is 500x1000 in portrait and the device is rotated in landscape, this
  /// variable contains the size 1000x500.
  @override
  final Size rotatedSize;

  @override
  String toString() {
    return 'ScreenState(on: $on, pending: $pending, rotation: $rotation, size: $size, rotatedSize: $rotatedSize)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_ScreenState &&
            (identical(other.on, on) || other.on == on) &&
            (identical(other.pending, pending) || other.pending == pending) &&
            (identical(other.rotation, rotation) ||
                other.rotation == rotation) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.rotatedSize, rotatedSize) ||
                other.rotatedSize == rotatedSize));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, on, pending, rotation, size, rotatedSize);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_ScreenStateCopyWith<_$_ScreenState> get copyWith =>
      __$$_ScreenStateCopyWithImpl<_$_ScreenState>(this, _$identity);
}

abstract class _ScreenState implements ScreenState {
  const factory _ScreenState(
      {required final bool on,
      required final bool pending,
      required final int rotation,
      required final Size size,
      required final Size rotatedSize}) = _$_ScreenState;

  @override
  bool get on;
  @override

  /// Turn on/off operations have not yet finished.
  bool get pending;
  @override

  /// Rotation expressed in clockwise quarter turns.
  int get rotation;
  @override

  /// The screen size, before rotation.
  Size get size;
  @override

  /// The screen size, after rotation.
  /// If the physical screen is 500x1000 in portrait and the device is rotated in landscape, this
  /// variable contains the size 1000x500.
  Size get rotatedSize;
  @override
  @JsonKey(ignore: true)
  _$$_ScreenStateCopyWith<_$_ScreenState> get copyWith =>
      throw _privateConstructorUsedError;
}

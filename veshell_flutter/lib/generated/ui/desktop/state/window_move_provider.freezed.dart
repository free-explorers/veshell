// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../ui/desktop/state/window_move_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$WindowMoveState {
  bool get moving => throw _privateConstructorUsedError;
  Offset get startPosition => throw _privateConstructorUsedError;
  Offset get movedPosition => throw _privateConstructorUsedError;
  Offset get delta => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $WindowMoveStateCopyWith<WindowMoveState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WindowMoveStateCopyWith<$Res> {
  factory $WindowMoveStateCopyWith(
          WindowMoveState value, $Res Function(WindowMoveState) then) =
      _$WindowMoveStateCopyWithImpl<$Res, WindowMoveState>;
  @useResult
  $Res call(
      {bool moving, Offset startPosition, Offset movedPosition, Offset delta});
}

/// @nodoc
class _$WindowMoveStateCopyWithImpl<$Res, $Val extends WindowMoveState>
    implements $WindowMoveStateCopyWith<$Res> {
  _$WindowMoveStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? moving = null,
    Object? startPosition = null,
    Object? movedPosition = null,
    Object? delta = null,
  }) {
    return _then(_value.copyWith(
      moving: null == moving
          ? _value.moving
          : moving // ignore: cast_nullable_to_non_nullable
              as bool,
      startPosition: null == startPosition
          ? _value.startPosition
          : startPosition // ignore: cast_nullable_to_non_nullable
              as Offset,
      movedPosition: null == movedPosition
          ? _value.movedPosition
          : movedPosition // ignore: cast_nullable_to_non_nullable
              as Offset,
      delta: null == delta
          ? _value.delta
          : delta // ignore: cast_nullable_to_non_nullable
              as Offset,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WindowMoveStateImplCopyWith<$Res>
    implements $WindowMoveStateCopyWith<$Res> {
  factory _$$WindowMoveStateImplCopyWith(_$WindowMoveStateImpl value,
          $Res Function(_$WindowMoveStateImpl) then) =
      __$$WindowMoveStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool moving, Offset startPosition, Offset movedPosition, Offset delta});
}

/// @nodoc
class __$$WindowMoveStateImplCopyWithImpl<$Res>
    extends _$WindowMoveStateCopyWithImpl<$Res, _$WindowMoveStateImpl>
    implements _$$WindowMoveStateImplCopyWith<$Res> {
  __$$WindowMoveStateImplCopyWithImpl(
      _$WindowMoveStateImpl _value, $Res Function(_$WindowMoveStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? moving = null,
    Object? startPosition = null,
    Object? movedPosition = null,
    Object? delta = null,
  }) {
    return _then(_$WindowMoveStateImpl(
      moving: null == moving
          ? _value.moving
          : moving // ignore: cast_nullable_to_non_nullable
              as bool,
      startPosition: null == startPosition
          ? _value.startPosition
          : startPosition // ignore: cast_nullable_to_non_nullable
              as Offset,
      movedPosition: null == movedPosition
          ? _value.movedPosition
          : movedPosition // ignore: cast_nullable_to_non_nullable
              as Offset,
      delta: null == delta
          ? _value.delta
          : delta // ignore: cast_nullable_to_non_nullable
              as Offset,
    ));
  }
}

/// @nodoc

class _$WindowMoveStateImpl implements _WindowMoveState {
  const _$WindowMoveStateImpl(
      {required this.moving,
      required this.startPosition,
      required this.movedPosition,
      required this.delta});

  @override
  final bool moving;
  @override
  final Offset startPosition;
  @override
  final Offset movedPosition;
  @override
  final Offset delta;

  @override
  String toString() {
    return 'WindowMoveState(moving: $moving, startPosition: $startPosition, movedPosition: $movedPosition, delta: $delta)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WindowMoveStateImpl &&
            (identical(other.moving, moving) || other.moving == moving) &&
            (identical(other.startPosition, startPosition) ||
                other.startPosition == startPosition) &&
            (identical(other.movedPosition, movedPosition) ||
                other.movedPosition == movedPosition) &&
            (identical(other.delta, delta) || other.delta == delta));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, moving, startPosition, movedPosition, delta);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WindowMoveStateImplCopyWith<_$WindowMoveStateImpl> get copyWith =>
      __$$WindowMoveStateImplCopyWithImpl<_$WindowMoveStateImpl>(
          this, _$identity);
}

abstract class _WindowMoveState implements WindowMoveState {
  const factory _WindowMoveState(
      {required final bool moving,
      required final Offset startPosition,
      required final Offset movedPosition,
      required final Offset delta}) = _$WindowMoveStateImpl;

  @override
  bool get moving;
  @override
  Offset get startPosition;
  @override
  Offset get movedPosition;
  @override
  Offset get delta;
  @override
  @JsonKey(ignore: true)
  _$$WindowMoveStateImplCopyWith<_$WindowMoveStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

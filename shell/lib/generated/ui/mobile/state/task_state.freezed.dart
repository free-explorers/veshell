// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../ui/mobile/state/task_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$TaskState {
  TaskDismissState get dismissState => throw _privateConstructorUsedError;
  Object get startDismissAnimation => throw _privateConstructorUsedError;
  Object get cancelDismissAnimation => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $TaskStateCopyWith<TaskState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskStateCopyWith<$Res> {
  factory $TaskStateCopyWith(TaskState value, $Res Function(TaskState) then) =
      _$TaskStateCopyWithImpl<$Res, TaskState>;
  @useResult
  $Res call(
      {TaskDismissState dismissState,
      Object startDismissAnimation,
      Object cancelDismissAnimation});
}

/// @nodoc
class _$TaskStateCopyWithImpl<$Res, $Val extends TaskState>
    implements $TaskStateCopyWith<$Res> {
  _$TaskStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dismissState = null,
    Object? startDismissAnimation = null,
    Object? cancelDismissAnimation = null,
  }) {
    return _then(_value.copyWith(
      dismissState: null == dismissState
          ? _value.dismissState
          : dismissState // ignore: cast_nullable_to_non_nullable
              as TaskDismissState,
      startDismissAnimation: null == startDismissAnimation
          ? _value.startDismissAnimation
          : startDismissAnimation,
      cancelDismissAnimation: null == cancelDismissAnimation
          ? _value.cancelDismissAnimation
          : cancelDismissAnimation,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskStateImplCopyWith<$Res>
    implements $TaskStateCopyWith<$Res> {
  factory _$$TaskStateImplCopyWith(
          _$TaskStateImpl value, $Res Function(_$TaskStateImpl) then) =
      __$$TaskStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {TaskDismissState dismissState,
      Object startDismissAnimation,
      Object cancelDismissAnimation});
}

/// @nodoc
class __$$TaskStateImplCopyWithImpl<$Res>
    extends _$TaskStateCopyWithImpl<$Res, _$TaskStateImpl>
    implements _$$TaskStateImplCopyWith<$Res> {
  __$$TaskStateImplCopyWithImpl(
      _$TaskStateImpl _value, $Res Function(_$TaskStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dismissState = null,
    Object? startDismissAnimation = null,
    Object? cancelDismissAnimation = null,
  }) {
    return _then(_$TaskStateImpl(
      dismissState: null == dismissState
          ? _value.dismissState
          : dismissState // ignore: cast_nullable_to_non_nullable
              as TaskDismissState,
      startDismissAnimation: null == startDismissAnimation
          ? _value.startDismissAnimation
          : startDismissAnimation,
      cancelDismissAnimation: null == cancelDismissAnimation
          ? _value.cancelDismissAnimation
          : cancelDismissAnimation,
    ));
  }
}

/// @nodoc

class _$TaskStateImpl implements _TaskState {
  const _$TaskStateImpl(
      {required this.dismissState,
      required this.startDismissAnimation,
      required this.cancelDismissAnimation});

  @override
  final TaskDismissState dismissState;
  @override
  final Object startDismissAnimation;
  @override
  final Object cancelDismissAnimation;

  @override
  String toString() {
    return 'TaskState(dismissState: $dismissState, startDismissAnimation: $startDismissAnimation, cancelDismissAnimation: $cancelDismissAnimation)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskStateImpl &&
            (identical(other.dismissState, dismissState) ||
                other.dismissState == dismissState) &&
            const DeepCollectionEquality()
                .equals(other.startDismissAnimation, startDismissAnimation) &&
            const DeepCollectionEquality()
                .equals(other.cancelDismissAnimation, cancelDismissAnimation));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      dismissState,
      const DeepCollectionEquality().hash(startDismissAnimation),
      const DeepCollectionEquality().hash(cancelDismissAnimation));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskStateImplCopyWith<_$TaskStateImpl> get copyWith =>
      __$$TaskStateImplCopyWithImpl<_$TaskStateImpl>(this, _$identity);
}

abstract class _TaskState implements TaskState {
  const factory _TaskState(
      {required final TaskDismissState dismissState,
      required final Object startDismissAnimation,
      required final Object cancelDismissAnimation}) = _$TaskStateImpl;

  @override
  TaskDismissState get dismissState;
  @override
  Object get startDismissAnimation;
  @override
  Object get cancelDismissAnimation;
  @override
  @JsonKey(ignore: true)
  _$$TaskStateImplCopyWith<_$TaskStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

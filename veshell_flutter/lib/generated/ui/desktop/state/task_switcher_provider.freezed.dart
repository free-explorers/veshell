// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../ui/desktop/state/task_switcher_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$TaskSwitcherState {
  bool get shown => throw _privateConstructorUsedError;
  int get index => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $TaskSwitcherStateCopyWith<TaskSwitcherState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskSwitcherStateCopyWith<$Res> {
  factory $TaskSwitcherStateCopyWith(
          TaskSwitcherState value, $Res Function(TaskSwitcherState) then) =
      _$TaskSwitcherStateCopyWithImpl<$Res, TaskSwitcherState>;
  @useResult
  $Res call({bool shown, int index});
}

/// @nodoc
class _$TaskSwitcherStateCopyWithImpl<$Res, $Val extends TaskSwitcherState>
    implements $TaskSwitcherStateCopyWith<$Res> {
  _$TaskSwitcherStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shown = null,
    Object? index = null,
  }) {
    return _then(_value.copyWith(
      shown: null == shown
          ? _value.shown
          : shown // ignore: cast_nullable_to_non_nullable
              as bool,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_TaskSwitcherStateCopyWith<$Res>
    implements $TaskSwitcherStateCopyWith<$Res> {
  factory _$$_TaskSwitcherStateCopyWith(_$_TaskSwitcherState value,
          $Res Function(_$_TaskSwitcherState) then) =
      __$$_TaskSwitcherStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool shown, int index});
}

/// @nodoc
class __$$_TaskSwitcherStateCopyWithImpl<$Res>
    extends _$TaskSwitcherStateCopyWithImpl<$Res, _$_TaskSwitcherState>
    implements _$$_TaskSwitcherStateCopyWith<$Res> {
  __$$_TaskSwitcherStateCopyWithImpl(
      _$_TaskSwitcherState _value, $Res Function(_$_TaskSwitcherState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shown = null,
    Object? index = null,
  }) {
    return _then(_$_TaskSwitcherState(
      shown: null == shown
          ? _value.shown
          : shown // ignore: cast_nullable_to_non_nullable
              as bool,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$_TaskSwitcherState implements _TaskSwitcherState {
  const _$_TaskSwitcherState({required this.shown, required this.index});

  @override
  final bool shown;
  @override
  final int index;

  @override
  String toString() {
    return 'TaskSwitcherState(shown: $shown, index: $index)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_TaskSwitcherState &&
            (identical(other.shown, shown) || other.shown == shown) &&
            (identical(other.index, index) || other.index == index));
  }

  @override
  int get hashCode => Object.hash(runtimeType, shown, index);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_TaskSwitcherStateCopyWith<_$_TaskSwitcherState> get copyWith =>
      __$$_TaskSwitcherStateCopyWithImpl<_$_TaskSwitcherState>(
          this, _$identity);
}

abstract class _TaskSwitcherState implements TaskSwitcherState {
  const factory _TaskSwitcherState(
      {required final bool shown,
      required final int index}) = _$_TaskSwitcherState;

  @override
  bool get shown;
  @override
  int get index;
  @override
  @JsonKey(ignore: true)
  _$$_TaskSwitcherStateCopyWith<_$_TaskSwitcherState> get copyWith =>
      throw _privateConstructorUsedError;
}

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../ui/mobile/state/task_switcher_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$TaskSwitcherState {
  bool get inOverview => throw _privateConstructorUsedError;
  double get scale => throw _privateConstructorUsedError;
  bool get disableUserControl =>
      throw _privateConstructorUsedError; // Disables the ability to switch between tasks using gestures.
  bool get areAnimationsPlaying => throw _privateConstructorUsedError;
  Object get constraintsChanged => throw _privateConstructorUsedError;

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
  $Res call(
      {bool inOverview,
      double scale,
      bool disableUserControl,
      bool areAnimationsPlaying,
      Object constraintsChanged});
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
    Object? inOverview = null,
    Object? scale = null,
    Object? disableUserControl = null,
    Object? areAnimationsPlaying = null,
    Object? constraintsChanged = null,
  }) {
    return _then(_value.copyWith(
      inOverview: null == inOverview
          ? _value.inOverview
          : inOverview // ignore: cast_nullable_to_non_nullable
              as bool,
      scale: null == scale
          ? _value.scale
          : scale // ignore: cast_nullable_to_non_nullable
              as double,
      disableUserControl: null == disableUserControl
          ? _value.disableUserControl
          : disableUserControl // ignore: cast_nullable_to_non_nullable
              as bool,
      areAnimationsPlaying: null == areAnimationsPlaying
          ? _value.areAnimationsPlaying
          : areAnimationsPlaying // ignore: cast_nullable_to_non_nullable
              as bool,
      constraintsChanged: null == constraintsChanged
          ? _value.constraintsChanged
          : constraintsChanged,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskSwitcherStateImplCopyWith<$Res>
    implements $TaskSwitcherStateCopyWith<$Res> {
  factory _$$TaskSwitcherStateImplCopyWith(_$TaskSwitcherStateImpl value,
          $Res Function(_$TaskSwitcherStateImpl) then) =
      __$$TaskSwitcherStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool inOverview,
      double scale,
      bool disableUserControl,
      bool areAnimationsPlaying,
      Object constraintsChanged});
}

/// @nodoc
class __$$TaskSwitcherStateImplCopyWithImpl<$Res>
    extends _$TaskSwitcherStateCopyWithImpl<$Res, _$TaskSwitcherStateImpl>
    implements _$$TaskSwitcherStateImplCopyWith<$Res> {
  __$$TaskSwitcherStateImplCopyWithImpl(_$TaskSwitcherStateImpl _value,
      $Res Function(_$TaskSwitcherStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inOverview = null,
    Object? scale = null,
    Object? disableUserControl = null,
    Object? areAnimationsPlaying = null,
    Object? constraintsChanged = null,
  }) {
    return _then(_$TaskSwitcherStateImpl(
      inOverview: null == inOverview
          ? _value.inOverview
          : inOverview // ignore: cast_nullable_to_non_nullable
              as bool,
      scale: null == scale
          ? _value.scale
          : scale // ignore: cast_nullable_to_non_nullable
              as double,
      disableUserControl: null == disableUserControl
          ? _value.disableUserControl
          : disableUserControl // ignore: cast_nullable_to_non_nullable
              as bool,
      areAnimationsPlaying: null == areAnimationsPlaying
          ? _value.areAnimationsPlaying
          : areAnimationsPlaying // ignore: cast_nullable_to_non_nullable
              as bool,
      constraintsChanged: null == constraintsChanged
          ? _value.constraintsChanged
          : constraintsChanged,
    ));
  }
}

/// @nodoc

class _$TaskSwitcherStateImpl implements _TaskSwitcherState {
  _$TaskSwitcherStateImpl(
      {required this.inOverview,
      required this.scale,
      required this.disableUserControl,
      required this.areAnimationsPlaying,
      required this.constraintsChanged});

  @override
  final bool inOverview;
  @override
  final double scale;
  @override
  final bool disableUserControl;
// Disables the ability to switch between tasks using gestures.
  @override
  final bool areAnimationsPlaying;
  @override
  final Object constraintsChanged;

  @override
  String toString() {
    return 'TaskSwitcherState(inOverview: $inOverview, scale: $scale, disableUserControl: $disableUserControl, areAnimationsPlaying: $areAnimationsPlaying, constraintsChanged: $constraintsChanged)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskSwitcherStateImpl &&
            (identical(other.inOverview, inOverview) ||
                other.inOverview == inOverview) &&
            (identical(other.scale, scale) || other.scale == scale) &&
            (identical(other.disableUserControl, disableUserControl) ||
                other.disableUserControl == disableUserControl) &&
            (identical(other.areAnimationsPlaying, areAnimationsPlaying) ||
                other.areAnimationsPlaying == areAnimationsPlaying) &&
            const DeepCollectionEquality()
                .equals(other.constraintsChanged, constraintsChanged));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      inOverview,
      scale,
      disableUserControl,
      areAnimationsPlaying,
      const DeepCollectionEquality().hash(constraintsChanged));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskSwitcherStateImplCopyWith<_$TaskSwitcherStateImpl> get copyWith =>
      __$$TaskSwitcherStateImplCopyWithImpl<_$TaskSwitcherStateImpl>(
          this, _$identity);
}

abstract class _TaskSwitcherState implements TaskSwitcherState {
  factory _TaskSwitcherState(
      {required final bool inOverview,
      required final double scale,
      required final bool disableUserControl,
      required final bool areAnimationsPlaying,
      required final Object constraintsChanged}) = _$TaskSwitcherStateImpl;

  @override
  bool get inOverview;
  @override
  double get scale;
  @override
  bool get disableUserControl;
  @override // Disables the ability to switch between tasks using gestures.
  bool get areAnimationsPlaying;
  @override
  Object get constraintsChanged;
  @override
  @JsonKey(ignore: true)
  _$$TaskSwitcherStateImplCopyWith<_$TaskSwitcherStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

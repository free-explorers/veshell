// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../ui/desktop/state/window_state_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$WindowProviderState {
  Tiling get tiling => throw _privateConstructorUsedError;
  GlobalKey<State<StatefulWidget>> get repaintBoundaryKey =>
      throw _privateConstructorUsedError;
  ui.Image? get snapshot => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $WindowProviderStateCopyWith<WindowProviderState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WindowProviderStateCopyWith<$Res> {
  factory $WindowProviderStateCopyWith(
          WindowProviderState value, $Res Function(WindowProviderState) then) =
      _$WindowProviderStateCopyWithImpl<$Res, WindowProviderState>;
  @useResult
  $Res call(
      {Tiling tiling,
      GlobalKey<State<StatefulWidget>> repaintBoundaryKey,
      ui.Image? snapshot});
}

/// @nodoc
class _$WindowProviderStateCopyWithImpl<$Res, $Val extends WindowProviderState>
    implements $WindowProviderStateCopyWith<$Res> {
  _$WindowProviderStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tiling = null,
    Object? repaintBoundaryKey = null,
    Object? snapshot = freezed,
  }) {
    return _then(_value.copyWith(
      tiling: null == tiling
          ? _value.tiling
          : tiling // ignore: cast_nullable_to_non_nullable
              as Tiling,
      repaintBoundaryKey: null == repaintBoundaryKey
          ? _value.repaintBoundaryKey
          : repaintBoundaryKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<State<StatefulWidget>>,
      snapshot: freezed == snapshot
          ? _value.snapshot
          : snapshot // ignore: cast_nullable_to_non_nullable
              as ui.Image?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WindowProviderStateImplCopyWith<$Res>
    implements $WindowProviderStateCopyWith<$Res> {
  factory _$$WindowProviderStateImplCopyWith(_$WindowProviderStateImpl value,
          $Res Function(_$WindowProviderStateImpl) then) =
      __$$WindowProviderStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Tiling tiling,
      GlobalKey<State<StatefulWidget>> repaintBoundaryKey,
      ui.Image? snapshot});
}

/// @nodoc
class __$$WindowProviderStateImplCopyWithImpl<$Res>
    extends _$WindowProviderStateCopyWithImpl<$Res, _$WindowProviderStateImpl>
    implements _$$WindowProviderStateImplCopyWith<$Res> {
  __$$WindowProviderStateImplCopyWithImpl(_$WindowProviderStateImpl _value,
      $Res Function(_$WindowProviderStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tiling = null,
    Object? repaintBoundaryKey = null,
    Object? snapshot = freezed,
  }) {
    return _then(_$WindowProviderStateImpl(
      tiling: null == tiling
          ? _value.tiling
          : tiling // ignore: cast_nullable_to_non_nullable
              as Tiling,
      repaintBoundaryKey: null == repaintBoundaryKey
          ? _value.repaintBoundaryKey
          : repaintBoundaryKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<State<StatefulWidget>>,
      snapshot: freezed == snapshot
          ? _value.snapshot
          : snapshot // ignore: cast_nullable_to_non_nullable
              as ui.Image?,
    ));
  }
}

/// @nodoc

class _$WindowProviderStateImpl implements _WindowProviderState {
  const _$WindowProviderStateImpl(
      {required this.tiling,
      required this.repaintBoundaryKey,
      required this.snapshot});

  @override
  final Tiling tiling;
  @override
  final GlobalKey<State<StatefulWidget>> repaintBoundaryKey;
  @override
  final ui.Image? snapshot;

  @override
  String toString() {
    return 'WindowProviderState(tiling: $tiling, repaintBoundaryKey: $repaintBoundaryKey, snapshot: $snapshot)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WindowProviderStateImpl &&
            (identical(other.tiling, tiling) || other.tiling == tiling) &&
            (identical(other.repaintBoundaryKey, repaintBoundaryKey) ||
                other.repaintBoundaryKey == repaintBoundaryKey) &&
            (identical(other.snapshot, snapshot) ||
                other.snapshot == snapshot));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, tiling, repaintBoundaryKey, snapshot);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WindowProviderStateImplCopyWith<_$WindowProviderStateImpl> get copyWith =>
      __$$WindowProviderStateImplCopyWithImpl<_$WindowProviderStateImpl>(
          this, _$identity);
}

abstract class _WindowProviderState implements WindowProviderState {
  const factory _WindowProviderState(
      {required final Tiling tiling,
      required final GlobalKey<State<StatefulWidget>> repaintBoundaryKey,
      required final ui.Image? snapshot}) = _$WindowProviderStateImpl;

  @override
  Tiling get tiling;
  @override
  GlobalKey<State<StatefulWidget>> get repaintBoundaryKey;
  @override
  ui.Image? get snapshot;
  @override
  @JsonKey(ignore: true)
  _$$WindowProviderStateImplCopyWith<_$WindowProviderStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

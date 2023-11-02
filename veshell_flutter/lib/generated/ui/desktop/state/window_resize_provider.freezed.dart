// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../ui/desktop/state/window_resize_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$ResizerState {
  bool get resizing => throw _privateConstructorUsedError;
  ResizeEdge? get resizeEdge => throw _privateConstructorUsedError;
  Size get startSize => throw _privateConstructorUsedError;
  Size get wantedSize => throw _privateConstructorUsedError;
  Offset get delta => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ResizerStateCopyWith<ResizerState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ResizerStateCopyWith<$Res> {
  factory $ResizerStateCopyWith(
          ResizerState value, $Res Function(ResizerState) then) =
      _$ResizerStateCopyWithImpl<$Res, ResizerState>;
  @useResult
  $Res call(
      {bool resizing,
      ResizeEdge? resizeEdge,
      Size startSize,
      Size wantedSize,
      Offset delta});
}

/// @nodoc
class _$ResizerStateCopyWithImpl<$Res, $Val extends ResizerState>
    implements $ResizerStateCopyWith<$Res> {
  _$ResizerStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? resizing = null,
    Object? resizeEdge = freezed,
    Object? startSize = null,
    Object? wantedSize = null,
    Object? delta = null,
  }) {
    return _then(_value.copyWith(
      resizing: null == resizing
          ? _value.resizing
          : resizing // ignore: cast_nullable_to_non_nullable
              as bool,
      resizeEdge: freezed == resizeEdge
          ? _value.resizeEdge
          : resizeEdge // ignore: cast_nullable_to_non_nullable
              as ResizeEdge?,
      startSize: null == startSize
          ? _value.startSize
          : startSize // ignore: cast_nullable_to_non_nullable
              as Size,
      wantedSize: null == wantedSize
          ? _value.wantedSize
          : wantedSize // ignore: cast_nullable_to_non_nullable
              as Size,
      delta: null == delta
          ? _value.delta
          : delta // ignore: cast_nullable_to_non_nullable
              as Offset,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_ResizerStateCopyWith<$Res>
    implements $ResizerStateCopyWith<$Res> {
  factory _$$_ResizerStateCopyWith(
          _$_ResizerState value, $Res Function(_$_ResizerState) then) =
      __$$_ResizerStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool resizing,
      ResizeEdge? resizeEdge,
      Size startSize,
      Size wantedSize,
      Offset delta});
}

/// @nodoc
class __$$_ResizerStateCopyWithImpl<$Res>
    extends _$ResizerStateCopyWithImpl<$Res, _$_ResizerState>
    implements _$$_ResizerStateCopyWith<$Res> {
  __$$_ResizerStateCopyWithImpl(
      _$_ResizerState _value, $Res Function(_$_ResizerState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? resizing = null,
    Object? resizeEdge = freezed,
    Object? startSize = null,
    Object? wantedSize = null,
    Object? delta = null,
  }) {
    return _then(_$_ResizerState(
      resizing: null == resizing
          ? _value.resizing
          : resizing // ignore: cast_nullable_to_non_nullable
              as bool,
      resizeEdge: freezed == resizeEdge
          ? _value.resizeEdge
          : resizeEdge // ignore: cast_nullable_to_non_nullable
              as ResizeEdge?,
      startSize: null == startSize
          ? _value.startSize
          : startSize // ignore: cast_nullable_to_non_nullable
              as Size,
      wantedSize: null == wantedSize
          ? _value.wantedSize
          : wantedSize // ignore: cast_nullable_to_non_nullable
              as Size,
      delta: null == delta
          ? _value.delta
          : delta // ignore: cast_nullable_to_non_nullable
              as Offset,
    ));
  }
}

/// @nodoc

class _$_ResizerState implements _ResizerState {
  const _$_ResizerState(
      {required this.resizing,
      required this.resizeEdge,
      required this.startSize,
      required this.wantedSize,
      required this.delta});

  @override
  final bool resizing;
  @override
  final ResizeEdge? resizeEdge;
  @override
  final Size startSize;
  @override
  final Size wantedSize;
  @override
  final Offset delta;

  @override
  String toString() {
    return 'ResizerState(resizing: $resizing, resizeEdge: $resizeEdge, startSize: $startSize, wantedSize: $wantedSize, delta: $delta)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_ResizerState &&
            (identical(other.resizing, resizing) ||
                other.resizing == resizing) &&
            (identical(other.resizeEdge, resizeEdge) ||
                other.resizeEdge == resizeEdge) &&
            (identical(other.startSize, startSize) ||
                other.startSize == startSize) &&
            (identical(other.wantedSize, wantedSize) ||
                other.wantedSize == wantedSize) &&
            (identical(other.delta, delta) || other.delta == delta));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, resizing, resizeEdge, startSize, wantedSize, delta);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_ResizerStateCopyWith<_$_ResizerState> get copyWith =>
      __$$_ResizerStateCopyWithImpl<_$_ResizerState>(this, _$identity);
}

abstract class _ResizerState implements ResizerState {
  const factory _ResizerState(
      {required final bool resizing,
      required final ResizeEdge? resizeEdge,
      required final Size startSize,
      required final Size wantedSize,
      required final Offset delta}) = _$_ResizerState;

  @override
  bool get resizing;
  @override
  ResizeEdge? get resizeEdge;
  @override
  Size get startSize;
  @override
  Size get wantedSize;
  @override
  Offset get delta;
  @override
  @JsonKey(ignore: true)
  _$$_ResizerStateCopyWith<_$_ResizerState> get copyWith =>
      throw _privateConstructorUsedError;
}

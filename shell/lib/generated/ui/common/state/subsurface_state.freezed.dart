// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../ui/common/state/subsurface_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$SubsurfaceState {
  bool get mapped => throw _privateConstructorUsedError;
  int get parent => throw _privateConstructorUsedError;
  Offset get position =>
      throw _privateConstructorUsedError; // relative to the parent
  Key get widgetKey => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $SubsurfaceStateCopyWith<SubsurfaceState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SubsurfaceStateCopyWith<$Res> {
  factory $SubsurfaceStateCopyWith(
          SubsurfaceState value, $Res Function(SubsurfaceState) then) =
      _$SubsurfaceStateCopyWithImpl<$Res, SubsurfaceState>;
  @useResult
  $Res call({bool mapped, int parent, Offset position, Key widgetKey});
}

/// @nodoc
class _$SubsurfaceStateCopyWithImpl<$Res, $Val extends SubsurfaceState>
    implements $SubsurfaceStateCopyWith<$Res> {
  _$SubsurfaceStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mapped = null,
    Object? parent = null,
    Object? position = null,
    Object? widgetKey = null,
  }) {
    return _then(_value.copyWith(
      mapped: null == mapped
          ? _value.mapped
          : mapped // ignore: cast_nullable_to_non_nullable
              as bool,
      parent: null == parent
          ? _value.parent
          : parent // ignore: cast_nullable_to_non_nullable
              as int,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as Offset,
      widgetKey: null == widgetKey
          ? _value.widgetKey
          : widgetKey // ignore: cast_nullable_to_non_nullable
              as Key,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SubsurfaceStateImplCopyWith<$Res>
    implements $SubsurfaceStateCopyWith<$Res> {
  factory _$$SubsurfaceStateImplCopyWith(_$SubsurfaceStateImpl value,
          $Res Function(_$SubsurfaceStateImpl) then) =
      __$$SubsurfaceStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool mapped, int parent, Offset position, Key widgetKey});
}

/// @nodoc
class __$$SubsurfaceStateImplCopyWithImpl<$Res>
    extends _$SubsurfaceStateCopyWithImpl<$Res, _$SubsurfaceStateImpl>
    implements _$$SubsurfaceStateImplCopyWith<$Res> {
  __$$SubsurfaceStateImplCopyWithImpl(
      _$SubsurfaceStateImpl _value, $Res Function(_$SubsurfaceStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mapped = null,
    Object? parent = null,
    Object? position = null,
    Object? widgetKey = null,
  }) {
    return _then(_$SubsurfaceStateImpl(
      mapped: null == mapped
          ? _value.mapped
          : mapped // ignore: cast_nullable_to_non_nullable
              as bool,
      parent: null == parent
          ? _value.parent
          : parent // ignore: cast_nullable_to_non_nullable
              as int,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as Offset,
      widgetKey: null == widgetKey
          ? _value.widgetKey
          : widgetKey // ignore: cast_nullable_to_non_nullable
              as Key,
    ));
  }
}

/// @nodoc

class _$SubsurfaceStateImpl implements _SubsurfaceState {
  const _$SubsurfaceStateImpl(
      {required this.mapped,
      required this.parent,
      required this.position,
      required this.widgetKey});

  @override
  final bool mapped;
  @override
  final int parent;
  @override
  final Offset position;
// relative to the parent
  @override
  final Key widgetKey;

  @override
  String toString() {
    return 'SubsurfaceState(mapped: $mapped, parent: $parent, position: $position, widgetKey: $widgetKey)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SubsurfaceStateImpl &&
            (identical(other.mapped, mapped) || other.mapped == mapped) &&
            (identical(other.parent, parent) || other.parent == parent) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.widgetKey, widgetKey) ||
                other.widgetKey == widgetKey));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, mapped, parent, position, widgetKey);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SubsurfaceStateImplCopyWith<_$SubsurfaceStateImpl> get copyWith =>
      __$$SubsurfaceStateImplCopyWithImpl<_$SubsurfaceStateImpl>(
          this, _$identity);
}

abstract class _SubsurfaceState implements SubsurfaceState {
  const factory _SubsurfaceState(
      {required final bool mapped,
      required final int parent,
      required final Offset position,
      required final Key widgetKey}) = _$SubsurfaceStateImpl;

  @override
  bool get mapped;
  @override
  int get parent;
  @override
  Offset get position;
  @override // relative to the parent
  Key get widgetKey;
  @override
  @JsonKey(ignore: true)
  _$$SubsurfaceStateImplCopyWith<_$SubsurfaceStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

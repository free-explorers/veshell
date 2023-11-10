// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../ui/mobile/state/virtual_keyboard_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$VirtualKeyboardState {
  bool get activated => throw _privateConstructorUsedError;
  Size get size => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $VirtualKeyboardStateCopyWith<VirtualKeyboardState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VirtualKeyboardStateCopyWith<$Res> {
  factory $VirtualKeyboardStateCopyWith(VirtualKeyboardState value,
          $Res Function(VirtualKeyboardState) then) =
      _$VirtualKeyboardStateCopyWithImpl<$Res, VirtualKeyboardState>;
  @useResult
  $Res call({bool activated, Size size});
}

/// @nodoc
class _$VirtualKeyboardStateCopyWithImpl<$Res,
        $Val extends VirtualKeyboardState>
    implements $VirtualKeyboardStateCopyWith<$Res> {
  _$VirtualKeyboardStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? activated = null,
    Object? size = null,
  }) {
    return _then(_value.copyWith(
      activated: null == activated
          ? _value.activated
          : activated // ignore: cast_nullable_to_non_nullable
              as bool,
      size: null == size
          ? _value.size
          : size // ignore: cast_nullable_to_non_nullable
              as Size,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VirtualKeyboardStateImplCopyWith<$Res>
    implements $VirtualKeyboardStateCopyWith<$Res> {
  factory _$$VirtualKeyboardStateImplCopyWith(_$VirtualKeyboardStateImpl value,
          $Res Function(_$VirtualKeyboardStateImpl) then) =
      __$$VirtualKeyboardStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool activated, Size size});
}

/// @nodoc
class __$$VirtualKeyboardStateImplCopyWithImpl<$Res>
    extends _$VirtualKeyboardStateCopyWithImpl<$Res, _$VirtualKeyboardStateImpl>
    implements _$$VirtualKeyboardStateImplCopyWith<$Res> {
  __$$VirtualKeyboardStateImplCopyWithImpl(_$VirtualKeyboardStateImpl _value,
      $Res Function(_$VirtualKeyboardStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? activated = null,
    Object? size = null,
  }) {
    return _then(_$VirtualKeyboardStateImpl(
      activated: null == activated
          ? _value.activated
          : activated // ignore: cast_nullable_to_non_nullable
              as bool,
      size: null == size
          ? _value.size
          : size // ignore: cast_nullable_to_non_nullable
              as Size,
    ));
  }
}

/// @nodoc

class _$VirtualKeyboardStateImpl implements _VirtualKeyboardState {
  const _$VirtualKeyboardStateImpl(
      {required this.activated, required this.size});

  @override
  final bool activated;
  @override
  final Size size;

  @override
  String toString() {
    return 'VirtualKeyboardState(activated: $activated, size: $size)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VirtualKeyboardStateImpl &&
            (identical(other.activated, activated) ||
                other.activated == activated) &&
            (identical(other.size, size) || other.size == size));
  }

  @override
  int get hashCode => Object.hash(runtimeType, activated, size);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$VirtualKeyboardStateImplCopyWith<_$VirtualKeyboardStateImpl>
      get copyWith =>
          __$$VirtualKeyboardStateImplCopyWithImpl<_$VirtualKeyboardStateImpl>(
              this, _$identity);
}

abstract class _VirtualKeyboardState implements VirtualKeyboardState {
  const factory _VirtualKeyboardState(
      {required final bool activated,
      required final Size size}) = _$VirtualKeyboardStateImpl;

  @override
  bool get activated;
  @override
  Size get size;
  @override
  @JsonKey(ignore: true)
  _$$VirtualKeyboardStateImplCopyWith<_$VirtualKeyboardStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}

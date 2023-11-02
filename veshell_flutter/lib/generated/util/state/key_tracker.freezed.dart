// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../util/state/key_tracker.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$KeyState {
  bool get isDown => throw _privateConstructorUsedError;
  Object get down => throw _privateConstructorUsedError;
  Object get longPress => throw _privateConstructorUsedError;
  Object get shortPress => throw _privateConstructorUsedError;
  Object get up => throw _privateConstructorUsedError;
  Timer? get longPressTimer => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $KeyStateCopyWith<KeyState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $KeyStateCopyWith<$Res> {
  factory $KeyStateCopyWith(KeyState value, $Res Function(KeyState) then) =
      _$KeyStateCopyWithImpl<$Res, KeyState>;
  @useResult
  $Res call(
      {bool isDown,
      Object down,
      Object longPress,
      Object shortPress,
      Object up,
      Timer? longPressTimer});
}

/// @nodoc
class _$KeyStateCopyWithImpl<$Res, $Val extends KeyState>
    implements $KeyStateCopyWith<$Res> {
  _$KeyStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isDown = null,
    Object? down = null,
    Object? longPress = null,
    Object? shortPress = null,
    Object? up = null,
    Object? longPressTimer = freezed,
  }) {
    return _then(_value.copyWith(
      isDown: null == isDown
          ? _value.isDown
          : isDown // ignore: cast_nullable_to_non_nullable
              as bool,
      down: null == down ? _value.down : down,
      longPress: null == longPress ? _value.longPress : longPress,
      shortPress: null == shortPress ? _value.shortPress : shortPress,
      up: null == up ? _value.up : up,
      longPressTimer: freezed == longPressTimer
          ? _value.longPressTimer
          : longPressTimer // ignore: cast_nullable_to_non_nullable
              as Timer?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_KeyStateCopyWith<$Res> implements $KeyStateCopyWith<$Res> {
  factory _$$_KeyStateCopyWith(
          _$_KeyState value, $Res Function(_$_KeyState) then) =
      __$$_KeyStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isDown,
      Object down,
      Object longPress,
      Object shortPress,
      Object up,
      Timer? longPressTimer});
}

/// @nodoc
class __$$_KeyStateCopyWithImpl<$Res>
    extends _$KeyStateCopyWithImpl<$Res, _$_KeyState>
    implements _$$_KeyStateCopyWith<$Res> {
  __$$_KeyStateCopyWithImpl(
      _$_KeyState _value, $Res Function(_$_KeyState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isDown = null,
    Object? down = null,
    Object? longPress = null,
    Object? shortPress = null,
    Object? up = null,
    Object? longPressTimer = freezed,
  }) {
    return _then(_$_KeyState(
      isDown: null == isDown
          ? _value.isDown
          : isDown // ignore: cast_nullable_to_non_nullable
              as bool,
      down: null == down ? _value.down : down,
      longPress: null == longPress ? _value.longPress : longPress,
      shortPress: null == shortPress ? _value.shortPress : shortPress,
      up: null == up ? _value.up : up,
      longPressTimer: freezed == longPressTimer
          ? _value.longPressTimer
          : longPressTimer // ignore: cast_nullable_to_non_nullable
              as Timer?,
    ));
  }
}

/// @nodoc

class _$_KeyState implements _KeyState {
  const _$_KeyState(
      {required this.isDown,
      required this.down,
      required this.longPress,
      required this.shortPress,
      required this.up,
      required this.longPressTimer});

  @override
  final bool isDown;
  @override
  final Object down;
  @override
  final Object longPress;
  @override
  final Object shortPress;
  @override
  final Object up;
  @override
  final Timer? longPressTimer;

  @override
  String toString() {
    return 'KeyState(isDown: $isDown, down: $down, longPress: $longPress, shortPress: $shortPress, up: $up, longPressTimer: $longPressTimer)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_KeyState &&
            (identical(other.isDown, isDown) || other.isDown == isDown) &&
            const DeepCollectionEquality().equals(other.down, down) &&
            const DeepCollectionEquality().equals(other.longPress, longPress) &&
            const DeepCollectionEquality()
                .equals(other.shortPress, shortPress) &&
            const DeepCollectionEquality().equals(other.up, up) &&
            (identical(other.longPressTimer, longPressTimer) ||
                other.longPressTimer == longPressTimer));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      isDown,
      const DeepCollectionEquality().hash(down),
      const DeepCollectionEquality().hash(longPress),
      const DeepCollectionEquality().hash(shortPress),
      const DeepCollectionEquality().hash(up),
      longPressTimer);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_KeyStateCopyWith<_$_KeyState> get copyWith =>
      __$$_KeyStateCopyWithImpl<_$_KeyState>(this, _$identity);
}

abstract class _KeyState implements KeyState {
  const factory _KeyState(
      {required final bool isDown,
      required final Object down,
      required final Object longPress,
      required final Object shortPress,
      required final Object up,
      required final Timer? longPressTimer}) = _$_KeyState;

  @override
  bool get isDown;
  @override
  Object get down;
  @override
  Object get longPress;
  @override
  Object get shortPress;
  @override
  Object get up;
  @override
  Timer? get longPressTimer;
  @override
  @JsonKey(ignore: true)
  _$$_KeyStateCopyWith<_$_KeyState> get copyWith =>
      throw _privateConstructorUsedError;
}

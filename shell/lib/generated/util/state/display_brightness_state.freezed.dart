// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../util/state/display_brightness_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$DisplayBrightnessState {
  bool get available => throw _privateConstructorUsedError;
  File get brightnessFile => throw _privateConstructorUsedError;
  int get maxBrightness => throw _privateConstructorUsedError;
  double get brightness => throw _privateConstructorUsedError;
  double get savedBrightness => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DisplayBrightnessStateCopyWith<DisplayBrightnessState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DisplayBrightnessStateCopyWith<$Res> {
  factory $DisplayBrightnessStateCopyWith(DisplayBrightnessState value,
          $Res Function(DisplayBrightnessState) then) =
      _$DisplayBrightnessStateCopyWithImpl<$Res, DisplayBrightnessState>;
  @useResult
  $Res call(
      {bool available,
      File brightnessFile,
      int maxBrightness,
      double brightness,
      double savedBrightness});
}

/// @nodoc
class _$DisplayBrightnessStateCopyWithImpl<$Res,
        $Val extends DisplayBrightnessState>
    implements $DisplayBrightnessStateCopyWith<$Res> {
  _$DisplayBrightnessStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? available = null,
    Object? brightnessFile = null,
    Object? maxBrightness = null,
    Object? brightness = null,
    Object? savedBrightness = null,
  }) {
    return _then(_value.copyWith(
      available: null == available
          ? _value.available
          : available // ignore: cast_nullable_to_non_nullable
              as bool,
      brightnessFile: null == brightnessFile
          ? _value.brightnessFile
          : brightnessFile // ignore: cast_nullable_to_non_nullable
              as File,
      maxBrightness: null == maxBrightness
          ? _value.maxBrightness
          : maxBrightness // ignore: cast_nullable_to_non_nullable
              as int,
      brightness: null == brightness
          ? _value.brightness
          : brightness // ignore: cast_nullable_to_non_nullable
              as double,
      savedBrightness: null == savedBrightness
          ? _value.savedBrightness
          : savedBrightness // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DisplayBrightnessStateImplCopyWith<$Res>
    implements $DisplayBrightnessStateCopyWith<$Res> {
  factory _$$DisplayBrightnessStateImplCopyWith(
          _$DisplayBrightnessStateImpl value,
          $Res Function(_$DisplayBrightnessStateImpl) then) =
      __$$DisplayBrightnessStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool available,
      File brightnessFile,
      int maxBrightness,
      double brightness,
      double savedBrightness});
}

/// @nodoc
class __$$DisplayBrightnessStateImplCopyWithImpl<$Res>
    extends _$DisplayBrightnessStateCopyWithImpl<$Res,
        _$DisplayBrightnessStateImpl>
    implements _$$DisplayBrightnessStateImplCopyWith<$Res> {
  __$$DisplayBrightnessStateImplCopyWithImpl(
      _$DisplayBrightnessStateImpl _value,
      $Res Function(_$DisplayBrightnessStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? available = null,
    Object? brightnessFile = null,
    Object? maxBrightness = null,
    Object? brightness = null,
    Object? savedBrightness = null,
  }) {
    return _then(_$DisplayBrightnessStateImpl(
      available: null == available
          ? _value.available
          : available // ignore: cast_nullable_to_non_nullable
              as bool,
      brightnessFile: null == brightnessFile
          ? _value.brightnessFile
          : brightnessFile // ignore: cast_nullable_to_non_nullable
              as File,
      maxBrightness: null == maxBrightness
          ? _value.maxBrightness
          : maxBrightness // ignore: cast_nullable_to_non_nullable
              as int,
      brightness: null == brightness
          ? _value.brightness
          : brightness // ignore: cast_nullable_to_non_nullable
              as double,
      savedBrightness: null == savedBrightness
          ? _value.savedBrightness
          : savedBrightness // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$DisplayBrightnessStateImpl implements _DisplayBrightnessState {
  const _$DisplayBrightnessStateImpl(
      {required this.available,
      required this.brightnessFile,
      required this.maxBrightness,
      required this.brightness,
      required this.savedBrightness});

  @override
  final bool available;
  @override
  final File brightnessFile;
  @override
  final int maxBrightness;
  @override
  final double brightness;
  @override
  final double savedBrightness;

  @override
  String toString() {
    return 'DisplayBrightnessState(available: $available, brightnessFile: $brightnessFile, maxBrightness: $maxBrightness, brightness: $brightness, savedBrightness: $savedBrightness)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DisplayBrightnessStateImpl &&
            (identical(other.available, available) ||
                other.available == available) &&
            (identical(other.brightnessFile, brightnessFile) ||
                other.brightnessFile == brightnessFile) &&
            (identical(other.maxBrightness, maxBrightness) ||
                other.maxBrightness == maxBrightness) &&
            (identical(other.brightness, brightness) ||
                other.brightness == brightness) &&
            (identical(other.savedBrightness, savedBrightness) ||
                other.savedBrightness == savedBrightness));
  }

  @override
  int get hashCode => Object.hash(runtimeType, available, brightnessFile,
      maxBrightness, brightness, savedBrightness);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DisplayBrightnessStateImplCopyWith<_$DisplayBrightnessStateImpl>
      get copyWith => __$$DisplayBrightnessStateImplCopyWithImpl<
          _$DisplayBrightnessStateImpl>(this, _$identity);
}

abstract class _DisplayBrightnessState implements DisplayBrightnessState {
  const factory _DisplayBrightnessState(
      {required final bool available,
      required final File brightnessFile,
      required final int maxBrightness,
      required final double brightness,
      required final double savedBrightness}) = _$DisplayBrightnessStateImpl;

  @override
  bool get available;
  @override
  File get brightnessFile;
  @override
  int get maxBrightness;
  @override
  double get brightness;
  @override
  double get savedBrightness;
  @override
  @JsonKey(ignore: true)
  _$$DisplayBrightnessStateImplCopyWith<_$DisplayBrightnessStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}

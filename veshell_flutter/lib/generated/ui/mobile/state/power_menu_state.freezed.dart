// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../ui/mobile/state/power_menu_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$PowerMenuState {
  OverlayEntry get overlayEntry => throw _privateConstructorUsedError;
  bool get overlayEntryInserted => throw _privateConstructorUsedError;
  bool get shown => throw _privateConstructorUsedError;
  Object get show => throw _privateConstructorUsedError;
  Object get hide => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PowerMenuStateCopyWith<PowerMenuState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PowerMenuStateCopyWith<$Res> {
  factory $PowerMenuStateCopyWith(
          PowerMenuState value, $Res Function(PowerMenuState) then) =
      _$PowerMenuStateCopyWithImpl<$Res, PowerMenuState>;
  @useResult
  $Res call(
      {OverlayEntry overlayEntry,
      bool overlayEntryInserted,
      bool shown,
      Object show,
      Object hide});
}

/// @nodoc
class _$PowerMenuStateCopyWithImpl<$Res, $Val extends PowerMenuState>
    implements $PowerMenuStateCopyWith<$Res> {
  _$PowerMenuStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? overlayEntry = null,
    Object? overlayEntryInserted = null,
    Object? shown = null,
    Object? show = null,
    Object? hide = null,
  }) {
    return _then(_value.copyWith(
      overlayEntry: null == overlayEntry
          ? _value.overlayEntry
          : overlayEntry // ignore: cast_nullable_to_non_nullable
              as OverlayEntry,
      overlayEntryInserted: null == overlayEntryInserted
          ? _value.overlayEntryInserted
          : overlayEntryInserted // ignore: cast_nullable_to_non_nullable
              as bool,
      shown: null == shown
          ? _value.shown
          : shown // ignore: cast_nullable_to_non_nullable
              as bool,
      show: null == show ? _value.show : show,
      hide: null == hide ? _value.hide : hide,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_PowerMenuStateCopyWith<$Res>
    implements $PowerMenuStateCopyWith<$Res> {
  factory _$$_PowerMenuStateCopyWith(
          _$_PowerMenuState value, $Res Function(_$_PowerMenuState) then) =
      __$$_PowerMenuStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {OverlayEntry overlayEntry,
      bool overlayEntryInserted,
      bool shown,
      Object show,
      Object hide});
}

/// @nodoc
class __$$_PowerMenuStateCopyWithImpl<$Res>
    extends _$PowerMenuStateCopyWithImpl<$Res, _$_PowerMenuState>
    implements _$$_PowerMenuStateCopyWith<$Res> {
  __$$_PowerMenuStateCopyWithImpl(
      _$_PowerMenuState _value, $Res Function(_$_PowerMenuState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? overlayEntry = null,
    Object? overlayEntryInserted = null,
    Object? shown = null,
    Object? show = null,
    Object? hide = null,
  }) {
    return _then(_$_PowerMenuState(
      overlayEntry: null == overlayEntry
          ? _value.overlayEntry
          : overlayEntry // ignore: cast_nullable_to_non_nullable
              as OverlayEntry,
      overlayEntryInserted: null == overlayEntryInserted
          ? _value.overlayEntryInserted
          : overlayEntryInserted // ignore: cast_nullable_to_non_nullable
              as bool,
      shown: null == shown
          ? _value.shown
          : shown // ignore: cast_nullable_to_non_nullable
              as bool,
      show: null == show ? _value.show : show,
      hide: null == hide ? _value.hide : hide,
    ));
  }
}

/// @nodoc

class _$_PowerMenuState implements _PowerMenuState {
  const _$_PowerMenuState(
      {required this.overlayEntry,
      required this.overlayEntryInserted,
      required this.shown,
      required this.show,
      required this.hide});

  @override
  final OverlayEntry overlayEntry;
  @override
  final bool overlayEntryInserted;
  @override
  final bool shown;
  @override
  final Object show;
  @override
  final Object hide;

  @override
  String toString() {
    return 'PowerMenuState(overlayEntry: $overlayEntry, overlayEntryInserted: $overlayEntryInserted, shown: $shown, show: $show, hide: $hide)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_PowerMenuState &&
            (identical(other.overlayEntry, overlayEntry) ||
                other.overlayEntry == overlayEntry) &&
            (identical(other.overlayEntryInserted, overlayEntryInserted) ||
                other.overlayEntryInserted == overlayEntryInserted) &&
            (identical(other.shown, shown) || other.shown == shown) &&
            const DeepCollectionEquality().equals(other.show, show) &&
            const DeepCollectionEquality().equals(other.hide, hide));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      overlayEntry,
      overlayEntryInserted,
      shown,
      const DeepCollectionEquality().hash(show),
      const DeepCollectionEquality().hash(hide));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_PowerMenuStateCopyWith<_$_PowerMenuState> get copyWith =>
      __$$_PowerMenuStateCopyWithImpl<_$_PowerMenuState>(this, _$identity);
}

abstract class _PowerMenuState implements PowerMenuState {
  const factory _PowerMenuState(
      {required final OverlayEntry overlayEntry,
      required final bool overlayEntryInserted,
      required final bool shown,
      required final Object show,
      required final Object hide}) = _$_PowerMenuState;

  @override
  OverlayEntry get overlayEntry;
  @override
  bool get overlayEntryInserted;
  @override
  bool get shown;
  @override
  Object get show;
  @override
  Object get hide;
  @override
  @JsonKey(ignore: true)
  _$$_PowerMenuStateCopyWith<_$_PowerMenuState> get copyWith =>
      throw _privateConstructorUsedError;
}

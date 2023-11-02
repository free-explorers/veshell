// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../../../../ui/common/state/xdg_popup_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$XdgPopupState {
  int get parentViewId => throw _privateConstructorUsedError;
  Offset get position => throw _privateConstructorUsedError;
  GlobalKey<AnimationsState> get animationsKey =>
      throw _privateConstructorUsedError;
  bool get isClosing => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $XdgPopupStateCopyWith<XdgPopupState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $XdgPopupStateCopyWith<$Res> {
  factory $XdgPopupStateCopyWith(
          XdgPopupState value, $Res Function(XdgPopupState) then) =
      _$XdgPopupStateCopyWithImpl<$Res, XdgPopupState>;
  @useResult
  $Res call(
      {int parentViewId,
      Offset position,
      GlobalKey<AnimationsState> animationsKey,
      bool isClosing});
}

/// @nodoc
class _$XdgPopupStateCopyWithImpl<$Res, $Val extends XdgPopupState>
    implements $XdgPopupStateCopyWith<$Res> {
  _$XdgPopupStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? parentViewId = null,
    Object? position = null,
    Object? animationsKey = null,
    Object? isClosing = null,
  }) {
    return _then(_value.copyWith(
      parentViewId: null == parentViewId
          ? _value.parentViewId
          : parentViewId // ignore: cast_nullable_to_non_nullable
              as int,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as Offset,
      animationsKey: null == animationsKey
          ? _value.animationsKey
          : animationsKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<AnimationsState>,
      isClosing: null == isClosing
          ? _value.isClosing
          : isClosing // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_XdgPopupStateCopyWith<$Res>
    implements $XdgPopupStateCopyWith<$Res> {
  factory _$$_XdgPopupStateCopyWith(
          _$_XdgPopupState value, $Res Function(_$_XdgPopupState) then) =
      __$$_XdgPopupStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int parentViewId,
      Offset position,
      GlobalKey<AnimationsState> animationsKey,
      bool isClosing});
}

/// @nodoc
class __$$_XdgPopupStateCopyWithImpl<$Res>
    extends _$XdgPopupStateCopyWithImpl<$Res, _$_XdgPopupState>
    implements _$$_XdgPopupStateCopyWith<$Res> {
  __$$_XdgPopupStateCopyWithImpl(
      _$_XdgPopupState _value, $Res Function(_$_XdgPopupState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? parentViewId = null,
    Object? position = null,
    Object? animationsKey = null,
    Object? isClosing = null,
  }) {
    return _then(_$_XdgPopupState(
      parentViewId: null == parentViewId
          ? _value.parentViewId
          : parentViewId // ignore: cast_nullable_to_non_nullable
              as int,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as Offset,
      animationsKey: null == animationsKey
          ? _value.animationsKey
          : animationsKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<AnimationsState>,
      isClosing: null == isClosing
          ? _value.isClosing
          : isClosing // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$_XdgPopupState with DiagnosticableTreeMixin implements _XdgPopupState {
  const _$_XdgPopupState(
      {required this.parentViewId,
      required this.position,
      required this.animationsKey,
      required this.isClosing});

  @override
  final int parentViewId;
  @override
  final Offset position;
  @override
  final GlobalKey<AnimationsState> animationsKey;
  @override
  final bool isClosing;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'XdgPopupState(parentViewId: $parentViewId, position: $position, animationsKey: $animationsKey, isClosing: $isClosing)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'XdgPopupState'))
      ..add(DiagnosticsProperty('parentViewId', parentViewId))
      ..add(DiagnosticsProperty('position', position))
      ..add(DiagnosticsProperty('animationsKey', animationsKey))
      ..add(DiagnosticsProperty('isClosing', isClosing));
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_XdgPopupState &&
            (identical(other.parentViewId, parentViewId) ||
                other.parentViewId == parentViewId) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.animationsKey, animationsKey) ||
                other.animationsKey == animationsKey) &&
            (identical(other.isClosing, isClosing) ||
                other.isClosing == isClosing));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, parentViewId, position, animationsKey, isClosing);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_XdgPopupStateCopyWith<_$_XdgPopupState> get copyWith =>
      __$$_XdgPopupStateCopyWithImpl<_$_XdgPopupState>(this, _$identity);
}

abstract class _XdgPopupState implements XdgPopupState {
  const factory _XdgPopupState(
      {required final int parentViewId,
      required final Offset position,
      required final GlobalKey<AnimationsState> animationsKey,
      required final bool isClosing}) = _$_XdgPopupState;

  @override
  int get parentViewId;
  @override
  Offset get position;
  @override
  GlobalKey<AnimationsState> get animationsKey;
  @override
  bool get isClosing;
  @override
  @JsonKey(ignore: true)
  _$$_XdgPopupStateCopyWith<_$_XdgPopupState> get copyWith =>
      throw _privateConstructorUsedError;
}

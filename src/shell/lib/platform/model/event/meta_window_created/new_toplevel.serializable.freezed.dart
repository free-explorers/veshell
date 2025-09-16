// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'new_toplevel.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NewToplevelMessage _$NewToplevelMessageFromJson(Map<String, dynamic> json) {
  return _NewToplevelMessage.fromJson(json);
}

/// @nodoc
mixin _$NewToplevelMessage {
  int get surfaceId => throw _privateConstructorUsedError;
  int get pid => throw _privateConstructorUsedError;

  /// Serializes this NewToplevelMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NewToplevelMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NewToplevelMessageCopyWith<NewToplevelMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NewToplevelMessageCopyWith<$Res> {
  factory $NewToplevelMessageCopyWith(
          NewToplevelMessage value, $Res Function(NewToplevelMessage) then) =
      _$NewToplevelMessageCopyWithImpl<$Res, NewToplevelMessage>;
  @useResult
  $Res call({int surfaceId, int pid});
}

/// @nodoc
class _$NewToplevelMessageCopyWithImpl<$Res, $Val extends NewToplevelMessage>
    implements $NewToplevelMessageCopyWith<$Res> {
  _$NewToplevelMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NewToplevelMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? surfaceId = null,
    Object? pid = null,
  }) {
    return _then(_value.copyWith(
      surfaceId: null == surfaceId
          ? _value.surfaceId
          : surfaceId // ignore: cast_nullable_to_non_nullable
              as int,
      pid: null == pid
          ? _value.pid
          : pid // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NewToplevelMessageImplCopyWith<$Res>
    implements $NewToplevelMessageCopyWith<$Res> {
  factory _$$NewToplevelMessageImplCopyWith(_$NewToplevelMessageImpl value,
          $Res Function(_$NewToplevelMessageImpl) then) =
      __$$NewToplevelMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int surfaceId, int pid});
}

/// @nodoc
class __$$NewToplevelMessageImplCopyWithImpl<$Res>
    extends _$NewToplevelMessageCopyWithImpl<$Res, _$NewToplevelMessageImpl>
    implements _$$NewToplevelMessageImplCopyWith<$Res> {
  __$$NewToplevelMessageImplCopyWithImpl(_$NewToplevelMessageImpl _value,
      $Res Function(_$NewToplevelMessageImpl) _then)
      : super(_value, _then);

  /// Create a copy of NewToplevelMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? surfaceId = null,
    Object? pid = null,
  }) {
    return _then(_$NewToplevelMessageImpl(
      surfaceId: null == surfaceId
          ? _value.surfaceId
          : surfaceId // ignore: cast_nullable_to_non_nullable
              as int,
      pid: null == pid
          ? _value.pid
          : pid // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NewToplevelMessageImpl implements _NewToplevelMessage {
  _$NewToplevelMessageImpl({required this.surfaceId, required this.pid});

  factory _$NewToplevelMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$NewToplevelMessageImplFromJson(json);

  @override
  final int surfaceId;
  @override
  final int pid;

  @override
  String toString() {
    return 'NewToplevelMessage(surfaceId: $surfaceId, pid: $pid)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NewToplevelMessageImpl &&
            (identical(other.surfaceId, surfaceId) ||
                other.surfaceId == surfaceId) &&
            (identical(other.pid, pid) || other.pid == pid));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, surfaceId, pid);

  /// Create a copy of NewToplevelMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NewToplevelMessageImplCopyWith<_$NewToplevelMessageImpl> get copyWith =>
      __$$NewToplevelMessageImplCopyWithImpl<_$NewToplevelMessageImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NewToplevelMessageImplToJson(
      this,
    );
  }
}

abstract class _NewToplevelMessage implements NewToplevelMessage {
  factory _NewToplevelMessage(
      {required final int surfaceId,
      required final int pid}) = _$NewToplevelMessageImpl;

  factory _NewToplevelMessage.fromJson(Map<String, dynamic> json) =
      _$NewToplevelMessageImpl.fromJson;

  @override
  int get surfaceId;
  @override
  int get pid;

  /// Create a copy of NewToplevelMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NewToplevelMessageImplCopyWith<_$NewToplevelMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

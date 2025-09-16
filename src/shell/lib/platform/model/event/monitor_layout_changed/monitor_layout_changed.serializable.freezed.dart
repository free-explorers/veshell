// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monitor_layout_changed.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MonitorLayoutChangedMessage {

 List<Monitor> get monitors;
/// Create a copy of MonitorLayoutChangedMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MonitorLayoutChangedMessageCopyWith<MonitorLayoutChangedMessage> get copyWith => _$MonitorLayoutChangedMessageCopyWithImpl<MonitorLayoutChangedMessage>(this as MonitorLayoutChangedMessage, _$identity);

  /// Serializes this MonitorLayoutChangedMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MonitorLayoutChangedMessage&&const DeepCollectionEquality().equals(other.monitors, monitors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(monitors));

@override
String toString() {
  return 'MonitorLayoutChangedMessage(monitors: $monitors)';
}


}

/// @nodoc
abstract mixin class $MonitorLayoutChangedMessageCopyWith<$Res>  {
  factory $MonitorLayoutChangedMessageCopyWith(MonitorLayoutChangedMessage value, $Res Function(MonitorLayoutChangedMessage) _then) = _$MonitorLayoutChangedMessageCopyWithImpl;
@useResult
$Res call({
 List<Monitor> monitors
});




}
/// @nodoc
class _$MonitorLayoutChangedMessageCopyWithImpl<$Res>
    implements $MonitorLayoutChangedMessageCopyWith<$Res> {
  _$MonitorLayoutChangedMessageCopyWithImpl(this._self, this._then);

  final MonitorLayoutChangedMessage _self;
  final $Res Function(MonitorLayoutChangedMessage) _then;

/// Create a copy of MonitorLayoutChangedMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? monitors = null,}) {
  return _then(_self.copyWith(
monitors: null == monitors ? _self.monitors : monitors // ignore: cast_nullable_to_non_nullable
as List<Monitor>,
  ));
}

}


/// Adds pattern-matching-related methods to [MonitorLayoutChangedMessage].
extension MonitorLayoutChangedMessagePatterns on MonitorLayoutChangedMessage {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MonitorLayoutChangedMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MonitorLayoutChangedMessage() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MonitorLayoutChangedMessage value)  $default,){
final _that = this;
switch (_that) {
case _MonitorLayoutChangedMessage():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MonitorLayoutChangedMessage value)?  $default,){
final _that = this;
switch (_that) {
case _MonitorLayoutChangedMessage() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Monitor> monitors)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MonitorLayoutChangedMessage() when $default != null:
return $default(_that.monitors);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Monitor> monitors)  $default,) {final _that = this;
switch (_that) {
case _MonitorLayoutChangedMessage():
return $default(_that.monitors);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Monitor> monitors)?  $default,) {final _that = this;
switch (_that) {
case _MonitorLayoutChangedMessage() when $default != null:
return $default(_that.monitors);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MonitorLayoutChangedMessage implements MonitorLayoutChangedMessage {
   _MonitorLayoutChangedMessage({required final  List<Monitor> monitors}): _monitors = monitors;
  factory _MonitorLayoutChangedMessage.fromJson(Map<String, dynamic> json) => _$MonitorLayoutChangedMessageFromJson(json);

 final  List<Monitor> _monitors;
@override List<Monitor> get monitors {
  if (_monitors is EqualUnmodifiableListView) return _monitors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_monitors);
}


/// Create a copy of MonitorLayoutChangedMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MonitorLayoutChangedMessageCopyWith<_MonitorLayoutChangedMessage> get copyWith => __$MonitorLayoutChangedMessageCopyWithImpl<_MonitorLayoutChangedMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MonitorLayoutChangedMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MonitorLayoutChangedMessage&&const DeepCollectionEquality().equals(other._monitors, _monitors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_monitors));

@override
String toString() {
  return 'MonitorLayoutChangedMessage(monitors: $monitors)';
}


}

/// @nodoc
abstract mixin class _$MonitorLayoutChangedMessageCopyWith<$Res> implements $MonitorLayoutChangedMessageCopyWith<$Res> {
  factory _$MonitorLayoutChangedMessageCopyWith(_MonitorLayoutChangedMessage value, $Res Function(_MonitorLayoutChangedMessage) _then) = __$MonitorLayoutChangedMessageCopyWithImpl;
@override @useResult
$Res call({
 List<Monitor> monitors
});




}
/// @nodoc
class __$MonitorLayoutChangedMessageCopyWithImpl<$Res>
    implements _$MonitorLayoutChangedMessageCopyWith<$Res> {
  __$MonitorLayoutChangedMessageCopyWithImpl(this._self, this._then);

  final _MonitorLayoutChangedMessage _self;
  final $Res Function(_MonitorLayoutChangedMessage) _then;

/// Create a copy of MonitorLayoutChangedMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? monitors = null,}) {
  return _then(_MonitorLayoutChangedMessage(
monitors: null == monitors ? _self._monitors : monitors // ignore: cast_nullable_to_non_nullable
as List<Monitor>,
  ));
}


}

// dart format on

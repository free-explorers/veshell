// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dbus_notification.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DbusNotification {

 int? get pid; String get appName; int get replacesId; String get appIcon; String get summary; String get body; List<String> get actions; NotificationHints get hints; int get expireTimeout;
/// Create a copy of DbusNotification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DbusNotificationCopyWith<DbusNotification> get copyWith => _$DbusNotificationCopyWithImpl<DbusNotification>(this as DbusNotification, _$identity);

  /// Serializes this DbusNotification to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DbusNotification&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.appName, appName) || other.appName == appName)&&(identical(other.replacesId, replacesId) || other.replacesId == replacesId)&&(identical(other.appIcon, appIcon) || other.appIcon == appIcon)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other.actions, actions)&&(identical(other.hints, hints) || other.hints == hints)&&(identical(other.expireTimeout, expireTimeout) || other.expireTimeout == expireTimeout));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pid,appName,replacesId,appIcon,summary,body,const DeepCollectionEquality().hash(actions),hints,expireTimeout);

@override
String toString() {
  return 'DbusNotification(pid: $pid, appName: $appName, replacesId: $replacesId, appIcon: $appIcon, summary: $summary, body: $body, actions: $actions, hints: $hints, expireTimeout: $expireTimeout)';
}


}

/// @nodoc
abstract mixin class $DbusNotificationCopyWith<$Res>  {
  factory $DbusNotificationCopyWith(DbusNotification value, $Res Function(DbusNotification) _then) = _$DbusNotificationCopyWithImpl;
@useResult
$Res call({
 int? pid, String appName, int replacesId, String appIcon, String summary, String body, List<String> actions, NotificationHints hints, int expireTimeout
});


$NotificationHintsCopyWith<$Res> get hints;

}
/// @nodoc
class _$DbusNotificationCopyWithImpl<$Res>
    implements $DbusNotificationCopyWith<$Res> {
  _$DbusNotificationCopyWithImpl(this._self, this._then);

  final DbusNotification _self;
  final $Res Function(DbusNotification) _then;

/// Create a copy of DbusNotification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pid = freezed,Object? appName = null,Object? replacesId = null,Object? appIcon = null,Object? summary = null,Object? body = null,Object? actions = null,Object? hints = null,Object? expireTimeout = null,}) {
  return _then(_self.copyWith(
pid: freezed == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int?,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,replacesId: null == replacesId ? _self.replacesId : replacesId // ignore: cast_nullable_to_non_nullable
as int,appIcon: null == appIcon ? _self.appIcon : appIcon // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,actions: null == actions ? _self.actions : actions // ignore: cast_nullable_to_non_nullable
as List<String>,hints: null == hints ? _self.hints : hints // ignore: cast_nullable_to_non_nullable
as NotificationHints,expireTimeout: null == expireTimeout ? _self.expireTimeout : expireTimeout // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of DbusNotification
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationHintsCopyWith<$Res> get hints {
  
  return $NotificationHintsCopyWith<$Res>(_self.hints, (value) {
    return _then(_self.copyWith(hints: value));
  });
}
}


/// Adds pattern-matching-related methods to [DbusNotification].
extension DbusNotificationPatterns on DbusNotification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DbusNotification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DbusNotification() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DbusNotification value)  $default,){
final _that = this;
switch (_that) {
case _DbusNotification():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DbusNotification value)?  $default,){
final _that = this;
switch (_that) {
case _DbusNotification() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? pid,  String appName,  int replacesId,  String appIcon,  String summary,  String body,  List<String> actions,  NotificationHints hints,  int expireTimeout)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DbusNotification() when $default != null:
return $default(_that.pid,_that.appName,_that.replacesId,_that.appIcon,_that.summary,_that.body,_that.actions,_that.hints,_that.expireTimeout);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? pid,  String appName,  int replacesId,  String appIcon,  String summary,  String body,  List<String> actions,  NotificationHints hints,  int expireTimeout)  $default,) {final _that = this;
switch (_that) {
case _DbusNotification():
return $default(_that.pid,_that.appName,_that.replacesId,_that.appIcon,_that.summary,_that.body,_that.actions,_that.hints,_that.expireTimeout);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? pid,  String appName,  int replacesId,  String appIcon,  String summary,  String body,  List<String> actions,  NotificationHints hints,  int expireTimeout)?  $default,) {final _that = this;
switch (_that) {
case _DbusNotification() when $default != null:
return $default(_that.pid,_that.appName,_that.replacesId,_that.appIcon,_that.summary,_that.body,_that.actions,_that.hints,_that.expireTimeout);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DbusNotification implements DbusNotification {
  const _DbusNotification({required this.pid, required this.appName, required this.replacesId, required this.appIcon, required this.summary, required this.body, required final  List<String> actions, required this.hints, required this.expireTimeout}): _actions = actions;
  factory _DbusNotification.fromJson(Map<String, dynamic> json) => _$DbusNotificationFromJson(json);

@override final  int? pid;
@override final  String appName;
@override final  int replacesId;
@override final  String appIcon;
@override final  String summary;
@override final  String body;
 final  List<String> _actions;
@override List<String> get actions {
  if (_actions is EqualUnmodifiableListView) return _actions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_actions);
}

@override final  NotificationHints hints;
@override final  int expireTimeout;

/// Create a copy of DbusNotification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DbusNotificationCopyWith<_DbusNotification> get copyWith => __$DbusNotificationCopyWithImpl<_DbusNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DbusNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DbusNotification&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.appName, appName) || other.appName == appName)&&(identical(other.replacesId, replacesId) || other.replacesId == replacesId)&&(identical(other.appIcon, appIcon) || other.appIcon == appIcon)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other._actions, _actions)&&(identical(other.hints, hints) || other.hints == hints)&&(identical(other.expireTimeout, expireTimeout) || other.expireTimeout == expireTimeout));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pid,appName,replacesId,appIcon,summary,body,const DeepCollectionEquality().hash(_actions),hints,expireTimeout);

@override
String toString() {
  return 'DbusNotification(pid: $pid, appName: $appName, replacesId: $replacesId, appIcon: $appIcon, summary: $summary, body: $body, actions: $actions, hints: $hints, expireTimeout: $expireTimeout)';
}


}

/// @nodoc
abstract mixin class _$DbusNotificationCopyWith<$Res> implements $DbusNotificationCopyWith<$Res> {
  factory _$DbusNotificationCopyWith(_DbusNotification value, $Res Function(_DbusNotification) _then) = __$DbusNotificationCopyWithImpl;
@override @useResult
$Res call({
 int? pid, String appName, int replacesId, String appIcon, String summary, String body, List<String> actions, NotificationHints hints, int expireTimeout
});


@override $NotificationHintsCopyWith<$Res> get hints;

}
/// @nodoc
class __$DbusNotificationCopyWithImpl<$Res>
    implements _$DbusNotificationCopyWith<$Res> {
  __$DbusNotificationCopyWithImpl(this._self, this._then);

  final _DbusNotification _self;
  final $Res Function(_DbusNotification) _then;

/// Create a copy of DbusNotification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pid = freezed,Object? appName = null,Object? replacesId = null,Object? appIcon = null,Object? summary = null,Object? body = null,Object? actions = null,Object? hints = null,Object? expireTimeout = null,}) {
  return _then(_DbusNotification(
pid: freezed == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int?,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,replacesId: null == replacesId ? _self.replacesId : replacesId // ignore: cast_nullable_to_non_nullable
as int,appIcon: null == appIcon ? _self.appIcon : appIcon // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,actions: null == actions ? _self._actions : actions // ignore: cast_nullable_to_non_nullable
as List<String>,hints: null == hints ? _self.hints : hints // ignore: cast_nullable_to_non_nullable
as NotificationHints,expireTimeout: null == expireTimeout ? _self.expireTimeout : expireTimeout // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of DbusNotification
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationHintsCopyWith<$Res> get hints {
  
  return $NotificationHintsCopyWith<$Res>(_self.hints, (value) {
    return _then(_self.copyWith(hints: value));
  });
}
}

// dart format on

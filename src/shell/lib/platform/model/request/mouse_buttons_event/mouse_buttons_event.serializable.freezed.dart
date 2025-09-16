// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mouse_buttons_event.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MouseButtonsEventMessage {

 SurfaceId get surfaceId; IList<Button> get buttons;
/// Create a copy of MouseButtonsEventMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MouseButtonsEventMessageCopyWith<MouseButtonsEventMessage> get copyWith => _$MouseButtonsEventMessageCopyWithImpl<MouseButtonsEventMessage>(this as MouseButtonsEventMessage, _$identity);

  /// Serializes this MouseButtonsEventMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MouseButtonsEventMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&const DeepCollectionEquality().equals(other.buttons, buttons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId,const DeepCollectionEquality().hash(buttons));

@override
String toString() {
  return 'MouseButtonsEventMessage(surfaceId: $surfaceId, buttons: $buttons)';
}


}

/// @nodoc
abstract mixin class $MouseButtonsEventMessageCopyWith<$Res>  {
  factory $MouseButtonsEventMessageCopyWith(MouseButtonsEventMessage value, $Res Function(MouseButtonsEventMessage) _then) = _$MouseButtonsEventMessageCopyWithImpl;
@useResult
$Res call({
 SurfaceId surfaceId, IList<Button> buttons
});




}
/// @nodoc
class _$MouseButtonsEventMessageCopyWithImpl<$Res>
    implements $MouseButtonsEventMessageCopyWith<$Res> {
  _$MouseButtonsEventMessageCopyWithImpl(this._self, this._then);

  final MouseButtonsEventMessage _self;
  final $Res Function(MouseButtonsEventMessage) _then;

/// Create a copy of MouseButtonsEventMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? surfaceId = null,Object? buttons = null,}) {
  return _then(_self.copyWith(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,buttons: null == buttons ? _self.buttons : buttons // ignore: cast_nullable_to_non_nullable
as IList<Button>,
  ));
}

}


/// Adds pattern-matching-related methods to [MouseButtonsEventMessage].
extension MouseButtonsEventMessagePatterns on MouseButtonsEventMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MouseButtonsEventMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MouseButtonsEventMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MouseButtonsEventMessage value)  $default,){
final _that = this;
switch (_that) {
case _MouseButtonsEventMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MouseButtonsEventMessage value)?  $default,){
final _that = this;
switch (_that) {
case _MouseButtonsEventMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SurfaceId surfaceId,  IList<Button> buttons)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MouseButtonsEventMessage() when $default != null:
return $default(_that.surfaceId,_that.buttons);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SurfaceId surfaceId,  IList<Button> buttons)  $default,) {final _that = this;
switch (_that) {
case _MouseButtonsEventMessage():
return $default(_that.surfaceId,_that.buttons);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SurfaceId surfaceId,  IList<Button> buttons)?  $default,) {final _that = this;
switch (_that) {
case _MouseButtonsEventMessage() when $default != null:
return $default(_that.surfaceId,_that.buttons);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MouseButtonsEventMessage implements MouseButtonsEventMessage {
   _MouseButtonsEventMessage({required this.surfaceId, required this.buttons});
  factory _MouseButtonsEventMessage.fromJson(Map<String, dynamic> json) => _$MouseButtonsEventMessageFromJson(json);

@override final  SurfaceId surfaceId;
@override final  IList<Button> buttons;

/// Create a copy of MouseButtonsEventMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MouseButtonsEventMessageCopyWith<_MouseButtonsEventMessage> get copyWith => __$MouseButtonsEventMessageCopyWithImpl<_MouseButtonsEventMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MouseButtonsEventMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MouseButtonsEventMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&const DeepCollectionEquality().equals(other.buttons, buttons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId,const DeepCollectionEquality().hash(buttons));

@override
String toString() {
  return 'MouseButtonsEventMessage(surfaceId: $surfaceId, buttons: $buttons)';
}


}

/// @nodoc
abstract mixin class _$MouseButtonsEventMessageCopyWith<$Res> implements $MouseButtonsEventMessageCopyWith<$Res> {
  factory _$MouseButtonsEventMessageCopyWith(_MouseButtonsEventMessage value, $Res Function(_MouseButtonsEventMessage) _then) = __$MouseButtonsEventMessageCopyWithImpl;
@override @useResult
$Res call({
 SurfaceId surfaceId, IList<Button> buttons
});




}
/// @nodoc
class __$MouseButtonsEventMessageCopyWithImpl<$Res>
    implements _$MouseButtonsEventMessageCopyWith<$Res> {
  __$MouseButtonsEventMessageCopyWithImpl(this._self, this._then);

  final _MouseButtonsEventMessage _self;
  final $Res Function(_MouseButtonsEventMessage) _then;

/// Create a copy of MouseButtonsEventMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surfaceId = null,Object? buttons = null,}) {
  return _then(_MouseButtonsEventMessage(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,buttons: null == buttons ? _self.buttons : buttons // ignore: cast_nullable_to_non_nullable
as IList<Button>,
  ));
}


}


/// @nodoc
mixin _$Button {

 int get button; bool get isPressed;
/// Create a copy of Button
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ButtonCopyWith<Button> get copyWith => _$ButtonCopyWithImpl<Button>(this as Button, _$identity);

  /// Serializes this Button to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Button&&(identical(other.button, button) || other.button == button)&&(identical(other.isPressed, isPressed) || other.isPressed == isPressed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,button,isPressed);

@override
String toString() {
  return 'Button(button: $button, isPressed: $isPressed)';
}


}

/// @nodoc
abstract mixin class $ButtonCopyWith<$Res>  {
  factory $ButtonCopyWith(Button value, $Res Function(Button) _then) = _$ButtonCopyWithImpl;
@useResult
$Res call({
 int button, bool isPressed
});




}
/// @nodoc
class _$ButtonCopyWithImpl<$Res>
    implements $ButtonCopyWith<$Res> {
  _$ButtonCopyWithImpl(this._self, this._then);

  final Button _self;
  final $Res Function(Button) _then;

/// Create a copy of Button
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? button = null,Object? isPressed = null,}) {
  return _then(_self.copyWith(
button: null == button ? _self.button : button // ignore: cast_nullable_to_non_nullable
as int,isPressed: null == isPressed ? _self.isPressed : isPressed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Button].
extension ButtonPatterns on Button {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Button value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Button() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Button value)  $default,){
final _that = this;
switch (_that) {
case _Button():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Button value)?  $default,){
final _that = this;
switch (_that) {
case _Button() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int button,  bool isPressed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Button() when $default != null:
return $default(_that.button,_that.isPressed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int button,  bool isPressed)  $default,) {final _that = this;
switch (_that) {
case _Button():
return $default(_that.button,_that.isPressed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int button,  bool isPressed)?  $default,) {final _that = this;
switch (_that) {
case _Button() when $default != null:
return $default(_that.button,_that.isPressed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Button implements Button {
   _Button({required this.button, required this.isPressed});
  factory _Button.fromJson(Map<String, dynamic> json) => _$ButtonFromJson(json);

@override final  int button;
@override final  bool isPressed;

/// Create a copy of Button
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ButtonCopyWith<_Button> get copyWith => __$ButtonCopyWithImpl<_Button>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ButtonToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Button&&(identical(other.button, button) || other.button == button)&&(identical(other.isPressed, isPressed) || other.isPressed == isPressed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,button,isPressed);

@override
String toString() {
  return 'Button(button: $button, isPressed: $isPressed)';
}


}

/// @nodoc
abstract mixin class _$ButtonCopyWith<$Res> implements $ButtonCopyWith<$Res> {
  factory _$ButtonCopyWith(_Button value, $Res Function(_Button) _then) = __$ButtonCopyWithImpl;
@override @useResult
$Res call({
 int button, bool isPressed
});




}
/// @nodoc
class __$ButtonCopyWithImpl<$Res>
    implements _$ButtonCopyWith<$Res> {
  __$ButtonCopyWithImpl(this._self, this._then);

  final _Button _self;
  final $Res Function(_Button) _then;

/// Create a copy of Button
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? button = null,Object? isPressed = null,}) {
  return _then(_Button(
button: null == button ? _self.button : button // ignore: cast_nullable_to_non_nullable
as int,isPressed: null == isPressed ? _self.isPressed : isPressed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

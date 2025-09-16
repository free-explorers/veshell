// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monitor.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Monitor {

 MonitorId get name; String get description; PhysicalProperties get physicalProperties; double get scale;@OffsetIntConverter() Offset get location; Mode? get currentMode; Mode? get preferredMode; List<Mode> get modes; int get viewId;
/// Create a copy of Monitor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MonitorCopyWith<Monitor> get copyWith => _$MonitorCopyWithImpl<Monitor>(this as Monitor, _$identity);

  /// Serializes this Monitor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Monitor&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.physicalProperties, physicalProperties) || other.physicalProperties == physicalProperties)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.location, location) || other.location == location)&&(identical(other.currentMode, currentMode) || other.currentMode == currentMode)&&(identical(other.preferredMode, preferredMode) || other.preferredMode == preferredMode)&&const DeepCollectionEquality().equals(other.modes, modes)&&(identical(other.viewId, viewId) || other.viewId == viewId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,physicalProperties,scale,location,currentMode,preferredMode,const DeepCollectionEquality().hash(modes),viewId);

@override
String toString() {
  return 'Monitor(name: $name, description: $description, physicalProperties: $physicalProperties, scale: $scale, location: $location, currentMode: $currentMode, preferredMode: $preferredMode, modes: $modes, viewId: $viewId)';
}


}

/// @nodoc
abstract mixin class $MonitorCopyWith<$Res>  {
  factory $MonitorCopyWith(Monitor value, $Res Function(Monitor) _then) = _$MonitorCopyWithImpl;
@useResult
$Res call({
 MonitorId name, String description, PhysicalProperties physicalProperties, double scale,@OffsetIntConverter() Offset location, Mode? currentMode, Mode? preferredMode, List<Mode> modes, int viewId
});


$PhysicalPropertiesCopyWith<$Res> get physicalProperties;$ModeCopyWith<$Res>? get currentMode;$ModeCopyWith<$Res>? get preferredMode;

}
/// @nodoc
class _$MonitorCopyWithImpl<$Res>
    implements $MonitorCopyWith<$Res> {
  _$MonitorCopyWithImpl(this._self, this._then);

  final Monitor _self;
  final $Res Function(Monitor) _then;

/// Create a copy of Monitor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? physicalProperties = null,Object? scale = null,Object? location = null,Object? currentMode = freezed,Object? preferredMode = freezed,Object? modes = null,Object? viewId = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as MonitorId,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,physicalProperties: null == physicalProperties ? _self.physicalProperties : physicalProperties // ignore: cast_nullable_to_non_nullable
as PhysicalProperties,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as Offset,currentMode: freezed == currentMode ? _self.currentMode : currentMode // ignore: cast_nullable_to_non_nullable
as Mode?,preferredMode: freezed == preferredMode ? _self.preferredMode : preferredMode // ignore: cast_nullable_to_non_nullable
as Mode?,modes: null == modes ? _self.modes : modes // ignore: cast_nullable_to_non_nullable
as List<Mode>,viewId: null == viewId ? _self.viewId : viewId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of Monitor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PhysicalPropertiesCopyWith<$Res> get physicalProperties {
  
  return $PhysicalPropertiesCopyWith<$Res>(_self.physicalProperties, (value) {
    return _then(_self.copyWith(physicalProperties: value));
  });
}/// Create a copy of Monitor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModeCopyWith<$Res>? get currentMode {
    if (_self.currentMode == null) {
    return null;
  }

  return $ModeCopyWith<$Res>(_self.currentMode!, (value) {
    return _then(_self.copyWith(currentMode: value));
  });
}/// Create a copy of Monitor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModeCopyWith<$Res>? get preferredMode {
    if (_self.preferredMode == null) {
    return null;
  }

  return $ModeCopyWith<$Res>(_self.preferredMode!, (value) {
    return _then(_self.copyWith(preferredMode: value));
  });
}
}


/// Adds pattern-matching-related methods to [Monitor].
extension MonitorPatterns on Monitor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Monitor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Monitor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Monitor value)  $default,){
final _that = this;
switch (_that) {
case _Monitor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Monitor value)?  $default,){
final _that = this;
switch (_that) {
case _Monitor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MonitorId name,  String description,  PhysicalProperties physicalProperties,  double scale, @OffsetIntConverter()  Offset location,  Mode? currentMode,  Mode? preferredMode,  List<Mode> modes,  int viewId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Monitor() when $default != null:
return $default(_that.name,_that.description,_that.physicalProperties,_that.scale,_that.location,_that.currentMode,_that.preferredMode,_that.modes,_that.viewId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MonitorId name,  String description,  PhysicalProperties physicalProperties,  double scale, @OffsetIntConverter()  Offset location,  Mode? currentMode,  Mode? preferredMode,  List<Mode> modes,  int viewId)  $default,) {final _that = this;
switch (_that) {
case _Monitor():
return $default(_that.name,_that.description,_that.physicalProperties,_that.scale,_that.location,_that.currentMode,_that.preferredMode,_that.modes,_that.viewId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MonitorId name,  String description,  PhysicalProperties physicalProperties,  double scale, @OffsetIntConverter()  Offset location,  Mode? currentMode,  Mode? preferredMode,  List<Mode> modes,  int viewId)?  $default,) {final _that = this;
switch (_that) {
case _Monitor() when $default != null:
return $default(_that.name,_that.description,_that.physicalProperties,_that.scale,_that.location,_that.currentMode,_that.preferredMode,_that.modes,_that.viewId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Monitor extends Monitor {
   _Monitor({required this.name, required this.description, required this.physicalProperties, required this.scale, @OffsetIntConverter() required this.location, required this.currentMode, required this.preferredMode, required final  List<Mode> modes, required this.viewId}): _modes = modes,super._();
  factory _Monitor.fromJson(Map<String, dynamic> json) => _$MonitorFromJson(json);

@override final  MonitorId name;
@override final  String description;
@override final  PhysicalProperties physicalProperties;
@override final  double scale;
@override@OffsetIntConverter() final  Offset location;
@override final  Mode? currentMode;
@override final  Mode? preferredMode;
 final  List<Mode> _modes;
@override List<Mode> get modes {
  if (_modes is EqualUnmodifiableListView) return _modes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modes);
}

@override final  int viewId;

/// Create a copy of Monitor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MonitorCopyWith<_Monitor> get copyWith => __$MonitorCopyWithImpl<_Monitor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MonitorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Monitor&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.physicalProperties, physicalProperties) || other.physicalProperties == physicalProperties)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.location, location) || other.location == location)&&(identical(other.currentMode, currentMode) || other.currentMode == currentMode)&&(identical(other.preferredMode, preferredMode) || other.preferredMode == preferredMode)&&const DeepCollectionEquality().equals(other._modes, _modes)&&(identical(other.viewId, viewId) || other.viewId == viewId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,physicalProperties,scale,location,currentMode,preferredMode,const DeepCollectionEquality().hash(_modes),viewId);

@override
String toString() {
  return 'Monitor(name: $name, description: $description, physicalProperties: $physicalProperties, scale: $scale, location: $location, currentMode: $currentMode, preferredMode: $preferredMode, modes: $modes, viewId: $viewId)';
}


}

/// @nodoc
abstract mixin class _$MonitorCopyWith<$Res> implements $MonitorCopyWith<$Res> {
  factory _$MonitorCopyWith(_Monitor value, $Res Function(_Monitor) _then) = __$MonitorCopyWithImpl;
@override @useResult
$Res call({
 MonitorId name, String description, PhysicalProperties physicalProperties, double scale,@OffsetIntConverter() Offset location, Mode? currentMode, Mode? preferredMode, List<Mode> modes, int viewId
});


@override $PhysicalPropertiesCopyWith<$Res> get physicalProperties;@override $ModeCopyWith<$Res>? get currentMode;@override $ModeCopyWith<$Res>? get preferredMode;

}
/// @nodoc
class __$MonitorCopyWithImpl<$Res>
    implements _$MonitorCopyWith<$Res> {
  __$MonitorCopyWithImpl(this._self, this._then);

  final _Monitor _self;
  final $Res Function(_Monitor) _then;

/// Create a copy of Monitor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? physicalProperties = null,Object? scale = null,Object? location = null,Object? currentMode = freezed,Object? preferredMode = freezed,Object? modes = null,Object? viewId = null,}) {
  return _then(_Monitor(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as MonitorId,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,physicalProperties: null == physicalProperties ? _self.physicalProperties : physicalProperties // ignore: cast_nullable_to_non_nullable
as PhysicalProperties,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as Offset,currentMode: freezed == currentMode ? _self.currentMode : currentMode // ignore: cast_nullable_to_non_nullable
as Mode?,preferredMode: freezed == preferredMode ? _self.preferredMode : preferredMode // ignore: cast_nullable_to_non_nullable
as Mode?,modes: null == modes ? _self._modes : modes // ignore: cast_nullable_to_non_nullable
as List<Mode>,viewId: null == viewId ? _self.viewId : viewId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of Monitor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PhysicalPropertiesCopyWith<$Res> get physicalProperties {
  
  return $PhysicalPropertiesCopyWith<$Res>(_self.physicalProperties, (value) {
    return _then(_self.copyWith(physicalProperties: value));
  });
}/// Create a copy of Monitor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModeCopyWith<$Res>? get currentMode {
    if (_self.currentMode == null) {
    return null;
  }

  return $ModeCopyWith<$Res>(_self.currentMode!, (value) {
    return _then(_self.copyWith(currentMode: value));
  });
}/// Create a copy of Monitor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModeCopyWith<$Res>? get preferredMode {
    if (_self.preferredMode == null) {
    return null;
  }

  return $ModeCopyWith<$Res>(_self.preferredMode!, (value) {
    return _then(_self.copyWith(preferredMode: value));
  });
}
}


/// @nodoc
mixin _$Mode {

@SizeIntConverter() MonitorResolution get size; MonitorRefreshRate get refreshRate;
/// Create a copy of Mode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModeCopyWith<Mode> get copyWith => _$ModeCopyWithImpl<Mode>(this as Mode, _$identity);

  /// Serializes this Mode to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Mode&&(identical(other.size, size) || other.size == size)&&(identical(other.refreshRate, refreshRate) || other.refreshRate == refreshRate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,size,refreshRate);

@override
String toString() {
  return 'Mode(size: $size, refreshRate: $refreshRate)';
}


}

/// @nodoc
abstract mixin class $ModeCopyWith<$Res>  {
  factory $ModeCopyWith(Mode value, $Res Function(Mode) _then) = _$ModeCopyWithImpl;
@useResult
$Res call({
@SizeIntConverter() MonitorResolution size, MonitorRefreshRate refreshRate
});




}
/// @nodoc
class _$ModeCopyWithImpl<$Res>
    implements $ModeCopyWith<$Res> {
  _$ModeCopyWithImpl(this._self, this._then);

  final Mode _self;
  final $Res Function(Mode) _then;

/// Create a copy of Mode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? size = null,Object? refreshRate = null,}) {
  return _then(_self.copyWith(
size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as MonitorResolution,refreshRate: null == refreshRate ? _self.refreshRate : refreshRate // ignore: cast_nullable_to_non_nullable
as MonitorRefreshRate,
  ));
}

}


/// Adds pattern-matching-related methods to [Mode].
extension ModePatterns on Mode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Mode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Mode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Mode value)  $default,){
final _that = this;
switch (_that) {
case _Mode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Mode value)?  $default,){
final _that = this;
switch (_that) {
case _Mode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@SizeIntConverter()  MonitorResolution size,  MonitorRefreshRate refreshRate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Mode() when $default != null:
return $default(_that.size,_that.refreshRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@SizeIntConverter()  MonitorResolution size,  MonitorRefreshRate refreshRate)  $default,) {final _that = this;
switch (_that) {
case _Mode():
return $default(_that.size,_that.refreshRate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@SizeIntConverter()  MonitorResolution size,  MonitorRefreshRate refreshRate)?  $default,) {final _that = this;
switch (_that) {
case _Mode() when $default != null:
return $default(_that.size,_that.refreshRate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Mode implements Mode {
  const _Mode({@SizeIntConverter() required this.size, required this.refreshRate});
  factory _Mode.fromJson(Map<String, dynamic> json) => _$ModeFromJson(json);

@override@SizeIntConverter() final  MonitorResolution size;
@override final  MonitorRefreshRate refreshRate;

/// Create a copy of Mode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModeCopyWith<_Mode> get copyWith => __$ModeCopyWithImpl<_Mode>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Mode&&(identical(other.size, size) || other.size == size)&&(identical(other.refreshRate, refreshRate) || other.refreshRate == refreshRate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,size,refreshRate);

@override
String toString() {
  return 'Mode(size: $size, refreshRate: $refreshRate)';
}


}

/// @nodoc
abstract mixin class _$ModeCopyWith<$Res> implements $ModeCopyWith<$Res> {
  factory _$ModeCopyWith(_Mode value, $Res Function(_Mode) _then) = __$ModeCopyWithImpl;
@override @useResult
$Res call({
@SizeIntConverter() MonitorResolution size, MonitorRefreshRate refreshRate
});




}
/// @nodoc
class __$ModeCopyWithImpl<$Res>
    implements _$ModeCopyWith<$Res> {
  __$ModeCopyWithImpl(this._self, this._then);

  final _Mode _self;
  final $Res Function(_Mode) _then;

/// Create a copy of Mode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? size = null,Object? refreshRate = null,}) {
  return _then(_Mode(
size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as MonitorResolution,refreshRate: null == refreshRate ? _self.refreshRate : refreshRate // ignore: cast_nullable_to_non_nullable
as MonitorRefreshRate,
  ));
}


}


/// @nodoc
mixin _$PhysicalProperties {

@SizeIntConverter() Size get size; String get make; String get model;
/// Create a copy of PhysicalProperties
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhysicalPropertiesCopyWith<PhysicalProperties> get copyWith => _$PhysicalPropertiesCopyWithImpl<PhysicalProperties>(this as PhysicalProperties, _$identity);

  /// Serializes this PhysicalProperties to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhysicalProperties&&(identical(other.size, size) || other.size == size)&&(identical(other.make, make) || other.make == make)&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,size,make,model);

@override
String toString() {
  return 'PhysicalProperties(size: $size, make: $make, model: $model)';
}


}

/// @nodoc
abstract mixin class $PhysicalPropertiesCopyWith<$Res>  {
  factory $PhysicalPropertiesCopyWith(PhysicalProperties value, $Res Function(PhysicalProperties) _then) = _$PhysicalPropertiesCopyWithImpl;
@useResult
$Res call({
@SizeIntConverter() Size size, String make, String model
});




}
/// @nodoc
class _$PhysicalPropertiesCopyWithImpl<$Res>
    implements $PhysicalPropertiesCopyWith<$Res> {
  _$PhysicalPropertiesCopyWithImpl(this._self, this._then);

  final PhysicalProperties _self;
  final $Res Function(PhysicalProperties) _then;

/// Create a copy of PhysicalProperties
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? size = null,Object? make = null,Object? model = null,}) {
  return _then(_self.copyWith(
size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as Size,make: null == make ? _self.make : make // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PhysicalProperties].
extension PhysicalPropertiesPatterns on PhysicalProperties {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhysicalProperties value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhysicalProperties() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhysicalProperties value)  $default,){
final _that = this;
switch (_that) {
case _PhysicalProperties():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhysicalProperties value)?  $default,){
final _that = this;
switch (_that) {
case _PhysicalProperties() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@SizeIntConverter()  Size size,  String make,  String model)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhysicalProperties() when $default != null:
return $default(_that.size,_that.make,_that.model);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@SizeIntConverter()  Size size,  String make,  String model)  $default,) {final _that = this;
switch (_that) {
case _PhysicalProperties():
return $default(_that.size,_that.make,_that.model);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@SizeIntConverter()  Size size,  String make,  String model)?  $default,) {final _that = this;
switch (_that) {
case _PhysicalProperties() when $default != null:
return $default(_that.size,_that.make,_that.model);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PhysicalProperties implements PhysicalProperties {
  const _PhysicalProperties({@SizeIntConverter() required this.size, required this.make, required this.model});
  factory _PhysicalProperties.fromJson(Map<String, dynamic> json) => _$PhysicalPropertiesFromJson(json);

@override@SizeIntConverter() final  Size size;
@override final  String make;
@override final  String model;

/// Create a copy of PhysicalProperties
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhysicalPropertiesCopyWith<_PhysicalProperties> get copyWith => __$PhysicalPropertiesCopyWithImpl<_PhysicalProperties>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PhysicalPropertiesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhysicalProperties&&(identical(other.size, size) || other.size == size)&&(identical(other.make, make) || other.make == make)&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,size,make,model);

@override
String toString() {
  return 'PhysicalProperties(size: $size, make: $make, model: $model)';
}


}

/// @nodoc
abstract mixin class _$PhysicalPropertiesCopyWith<$Res> implements $PhysicalPropertiesCopyWith<$Res> {
  factory _$PhysicalPropertiesCopyWith(_PhysicalProperties value, $Res Function(_PhysicalProperties) _then) = __$PhysicalPropertiesCopyWithImpl;
@override @useResult
$Res call({
@SizeIntConverter() Size size, String make, String model
});




}
/// @nodoc
class __$PhysicalPropertiesCopyWithImpl<$Res>
    implements _$PhysicalPropertiesCopyWith<$Res> {
  __$PhysicalPropertiesCopyWithImpl(this._self, this._then);

  final _PhysicalProperties _self;
  final $Res Function(_PhysicalProperties) _then;

/// Create a copy of PhysicalProperties
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? size = null,Object? make = null,Object? model = null,}) {
  return _then(_PhysicalProperties(
size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as Size,make: null == make ? _self.make : make // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on

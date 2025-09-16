// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'commit_surface.serializable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CommitSurfaceMessage {

 SurfaceId get surfaceId; SurfaceRoleMessage? get role; TextureId get textureId; int get scale;@RectConverter() Rect get inputRegion; IList<int> get subsurfacesBelow; IList<int> get subsurfacesAbove;@OffsetConverter() Offset? get bufferDelta;@SizeConverter() Size? get bufferSize;
/// Create a copy of CommitSurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommitSurfaceMessageCopyWith<CommitSurfaceMessage> get copyWith => _$CommitSurfaceMessageCopyWithImpl<CommitSurfaceMessage>(this as CommitSurfaceMessage, _$identity);

  /// Serializes this CommitSurfaceMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommitSurfaceMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.role, role) || other.role == role)&&(identical(other.textureId, textureId) || other.textureId == textureId)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.inputRegion, inputRegion) || other.inputRegion == inputRegion)&&const DeepCollectionEquality().equals(other.subsurfacesBelow, subsurfacesBelow)&&const DeepCollectionEquality().equals(other.subsurfacesAbove, subsurfacesAbove)&&(identical(other.bufferDelta, bufferDelta) || other.bufferDelta == bufferDelta)&&(identical(other.bufferSize, bufferSize) || other.bufferSize == bufferSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId,role,textureId,scale,inputRegion,const DeepCollectionEquality().hash(subsurfacesBelow),const DeepCollectionEquality().hash(subsurfacesAbove),bufferDelta,bufferSize);

@override
String toString() {
  return 'CommitSurfaceMessage(surfaceId: $surfaceId, role: $role, textureId: $textureId, scale: $scale, inputRegion: $inputRegion, subsurfacesBelow: $subsurfacesBelow, subsurfacesAbove: $subsurfacesAbove, bufferDelta: $bufferDelta, bufferSize: $bufferSize)';
}


}

/// @nodoc
abstract mixin class $CommitSurfaceMessageCopyWith<$Res>  {
  factory $CommitSurfaceMessageCopyWith(CommitSurfaceMessage value, $Res Function(CommitSurfaceMessage) _then) = _$CommitSurfaceMessageCopyWithImpl;
@useResult
$Res call({
 SurfaceId surfaceId, SurfaceRoleMessage? role, TextureId textureId, int scale,@RectConverter() Rect inputRegion, IList<int> subsurfacesBelow, IList<int> subsurfacesAbove,@OffsetConverter() Offset? bufferDelta,@SizeConverter() Size? bufferSize
});


$SurfaceRoleMessageCopyWith<$Res>? get role;

}
/// @nodoc
class _$CommitSurfaceMessageCopyWithImpl<$Res>
    implements $CommitSurfaceMessageCopyWith<$Res> {
  _$CommitSurfaceMessageCopyWithImpl(this._self, this._then);

  final CommitSurfaceMessage _self;
  final $Res Function(CommitSurfaceMessage) _then;

/// Create a copy of CommitSurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? surfaceId = null,Object? role = freezed,Object? textureId = null,Object? scale = null,Object? inputRegion = null,Object? subsurfacesBelow = null,Object? subsurfacesAbove = null,Object? bufferDelta = freezed,Object? bufferSize = freezed,}) {
  return _then(_self.copyWith(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as SurfaceRoleMessage?,textureId: null == textureId ? _self.textureId : textureId // ignore: cast_nullable_to_non_nullable
as TextureId,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as int,inputRegion: null == inputRegion ? _self.inputRegion : inputRegion // ignore: cast_nullable_to_non_nullable
as Rect,subsurfacesBelow: null == subsurfacesBelow ? _self.subsurfacesBelow : subsurfacesBelow // ignore: cast_nullable_to_non_nullable
as IList<int>,subsurfacesAbove: null == subsurfacesAbove ? _self.subsurfacesAbove : subsurfacesAbove // ignore: cast_nullable_to_non_nullable
as IList<int>,bufferDelta: freezed == bufferDelta ? _self.bufferDelta : bufferDelta // ignore: cast_nullable_to_non_nullable
as Offset?,bufferSize: freezed == bufferSize ? _self.bufferSize : bufferSize // ignore: cast_nullable_to_non_nullable
as Size?,
  ));
}
/// Create a copy of CommitSurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SurfaceRoleMessageCopyWith<$Res>? get role {
    if (_self.role == null) {
    return null;
  }

  return $SurfaceRoleMessageCopyWith<$Res>(_self.role!, (value) {
    return _then(_self.copyWith(role: value));
  });
}
}


/// Adds pattern-matching-related methods to [CommitSurfaceMessage].
extension CommitSurfaceMessagePatterns on CommitSurfaceMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommitSurfaceMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommitSurfaceMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommitSurfaceMessage value)  $default,){
final _that = this;
switch (_that) {
case _CommitSurfaceMessage():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommitSurfaceMessage value)?  $default,){
final _that = this;
switch (_that) {
case _CommitSurfaceMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SurfaceId surfaceId,  SurfaceRoleMessage? role,  TextureId textureId,  int scale, @RectConverter()  Rect inputRegion,  IList<int> subsurfacesBelow,  IList<int> subsurfacesAbove, @OffsetConverter()  Offset? bufferDelta, @SizeConverter()  Size? bufferSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommitSurfaceMessage() when $default != null:
return $default(_that.surfaceId,_that.role,_that.textureId,_that.scale,_that.inputRegion,_that.subsurfacesBelow,_that.subsurfacesAbove,_that.bufferDelta,_that.bufferSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SurfaceId surfaceId,  SurfaceRoleMessage? role,  TextureId textureId,  int scale, @RectConverter()  Rect inputRegion,  IList<int> subsurfacesBelow,  IList<int> subsurfacesAbove, @OffsetConverter()  Offset? bufferDelta, @SizeConverter()  Size? bufferSize)  $default,) {final _that = this;
switch (_that) {
case _CommitSurfaceMessage():
return $default(_that.surfaceId,_that.role,_that.textureId,_that.scale,_that.inputRegion,_that.subsurfacesBelow,_that.subsurfacesAbove,_that.bufferDelta,_that.bufferSize);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SurfaceId surfaceId,  SurfaceRoleMessage? role,  TextureId textureId,  int scale, @RectConverter()  Rect inputRegion,  IList<int> subsurfacesBelow,  IList<int> subsurfacesAbove, @OffsetConverter()  Offset? bufferDelta, @SizeConverter()  Size? bufferSize)?  $default,) {final _that = this;
switch (_that) {
case _CommitSurfaceMessage() when $default != null:
return $default(_that.surfaceId,_that.role,_that.textureId,_that.scale,_that.inputRegion,_that.subsurfacesBelow,_that.subsurfacesAbove,_that.bufferDelta,_that.bufferSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommitSurfaceMessage implements CommitSurfaceMessage {
   _CommitSurfaceMessage({required this.surfaceId, required this.role, required this.textureId, required this.scale, @RectConverter() required this.inputRegion, required this.subsurfacesBelow, required this.subsurfacesAbove, @OffsetConverter() this.bufferDelta, @SizeConverter() this.bufferSize});
  factory _CommitSurfaceMessage.fromJson(Map<String, dynamic> json) => _$CommitSurfaceMessageFromJson(json);

@override final  SurfaceId surfaceId;
@override final  SurfaceRoleMessage? role;
@override final  TextureId textureId;
@override final  int scale;
@override@RectConverter() final  Rect inputRegion;
@override final  IList<int> subsurfacesBelow;
@override final  IList<int> subsurfacesAbove;
@override@OffsetConverter() final  Offset? bufferDelta;
@override@SizeConverter() final  Size? bufferSize;

/// Create a copy of CommitSurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommitSurfaceMessageCopyWith<_CommitSurfaceMessage> get copyWith => __$CommitSurfaceMessageCopyWithImpl<_CommitSurfaceMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommitSurfaceMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommitSurfaceMessage&&(identical(other.surfaceId, surfaceId) || other.surfaceId == surfaceId)&&(identical(other.role, role) || other.role == role)&&(identical(other.textureId, textureId) || other.textureId == textureId)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.inputRegion, inputRegion) || other.inputRegion == inputRegion)&&const DeepCollectionEquality().equals(other.subsurfacesBelow, subsurfacesBelow)&&const DeepCollectionEquality().equals(other.subsurfacesAbove, subsurfacesAbove)&&(identical(other.bufferDelta, bufferDelta) || other.bufferDelta == bufferDelta)&&(identical(other.bufferSize, bufferSize) || other.bufferSize == bufferSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surfaceId,role,textureId,scale,inputRegion,const DeepCollectionEquality().hash(subsurfacesBelow),const DeepCollectionEquality().hash(subsurfacesAbove),bufferDelta,bufferSize);

@override
String toString() {
  return 'CommitSurfaceMessage(surfaceId: $surfaceId, role: $role, textureId: $textureId, scale: $scale, inputRegion: $inputRegion, subsurfacesBelow: $subsurfacesBelow, subsurfacesAbove: $subsurfacesAbove, bufferDelta: $bufferDelta, bufferSize: $bufferSize)';
}


}

/// @nodoc
abstract mixin class _$CommitSurfaceMessageCopyWith<$Res> implements $CommitSurfaceMessageCopyWith<$Res> {
  factory _$CommitSurfaceMessageCopyWith(_CommitSurfaceMessage value, $Res Function(_CommitSurfaceMessage) _then) = __$CommitSurfaceMessageCopyWithImpl;
@override @useResult
$Res call({
 SurfaceId surfaceId, SurfaceRoleMessage? role, TextureId textureId, int scale,@RectConverter() Rect inputRegion, IList<int> subsurfacesBelow, IList<int> subsurfacesAbove,@OffsetConverter() Offset? bufferDelta,@SizeConverter() Size? bufferSize
});


@override $SurfaceRoleMessageCopyWith<$Res>? get role;

}
/// @nodoc
class __$CommitSurfaceMessageCopyWithImpl<$Res>
    implements _$CommitSurfaceMessageCopyWith<$Res> {
  __$CommitSurfaceMessageCopyWithImpl(this._self, this._then);

  final _CommitSurfaceMessage _self;
  final $Res Function(_CommitSurfaceMessage) _then;

/// Create a copy of CommitSurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surfaceId = null,Object? role = freezed,Object? textureId = null,Object? scale = null,Object? inputRegion = null,Object? subsurfacesBelow = null,Object? subsurfacesAbove = null,Object? bufferDelta = freezed,Object? bufferSize = freezed,}) {
  return _then(_CommitSurfaceMessage(
surfaceId: null == surfaceId ? _self.surfaceId : surfaceId // ignore: cast_nullable_to_non_nullable
as SurfaceId,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as SurfaceRoleMessage?,textureId: null == textureId ? _self.textureId : textureId // ignore: cast_nullable_to_non_nullable
as TextureId,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as int,inputRegion: null == inputRegion ? _self.inputRegion : inputRegion // ignore: cast_nullable_to_non_nullable
as Rect,subsurfacesBelow: null == subsurfacesBelow ? _self.subsurfacesBelow : subsurfacesBelow // ignore: cast_nullable_to_non_nullable
as IList<int>,subsurfacesAbove: null == subsurfacesAbove ? _self.subsurfacesAbove : subsurfacesAbove // ignore: cast_nullable_to_non_nullable
as IList<int>,bufferDelta: freezed == bufferDelta ? _self.bufferDelta : bufferDelta // ignore: cast_nullable_to_non_nullable
as Offset?,bufferSize: freezed == bufferSize ? _self.bufferSize : bufferSize // ignore: cast_nullable_to_non_nullable
as Size?,
  ));
}

/// Create a copy of CommitSurfaceMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SurfaceRoleMessageCopyWith<$Res>? get role {
    if (_self.role == null) {
    return null;
  }

  return $SurfaceRoleMessageCopyWith<$Res>(_self.role!, (value) {
    return _then(_self.copyWith(role: value));
  });
}
}

SurfaceRoleMessage _$SurfaceRoleMessageFromJson(
  Map<String, dynamic> json
) {
    return SubsurfaceRoleMessage.fromJson(
      json
    );
}

/// @nodoc
mixin _$SurfaceRoleMessage {

 SurfaceId get parent;@OffsetConverter() Offset get position;
/// Create a copy of SurfaceRoleMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SurfaceRoleMessageCopyWith<SurfaceRoleMessage> get copyWith => _$SurfaceRoleMessageCopyWithImpl<SurfaceRoleMessage>(this as SurfaceRoleMessage, _$identity);

  /// Serializes this SurfaceRoleMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SurfaceRoleMessage&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.position, position) || other.position == position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,parent,position);

@override
String toString() {
  return 'SurfaceRoleMessage(parent: $parent, position: $position)';
}


}

/// @nodoc
abstract mixin class $SurfaceRoleMessageCopyWith<$Res>  {
  factory $SurfaceRoleMessageCopyWith(SurfaceRoleMessage value, $Res Function(SurfaceRoleMessage) _then) = _$SurfaceRoleMessageCopyWithImpl;
@useResult
$Res call({
 SurfaceId parent,@OffsetConverter() Offset position
});




}
/// @nodoc
class _$SurfaceRoleMessageCopyWithImpl<$Res>
    implements $SurfaceRoleMessageCopyWith<$Res> {
  _$SurfaceRoleMessageCopyWithImpl(this._self, this._then);

  final SurfaceRoleMessage _self;
  final $Res Function(SurfaceRoleMessage) _then;

/// Create a copy of SurfaceRoleMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? parent = null,Object? position = null,}) {
  return _then(_self.copyWith(
parent: null == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as SurfaceId,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Offset,
  ));
}

}


/// Adds pattern-matching-related methods to [SurfaceRoleMessage].
extension SurfaceRoleMessagePatterns on SurfaceRoleMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SubsurfaceRoleMessage value)?  subsurface,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SubsurfaceRoleMessage() when subsurface != null:
return subsurface(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SubsurfaceRoleMessage value)  subsurface,}){
final _that = this;
switch (_that) {
case SubsurfaceRoleMessage():
return subsurface(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SubsurfaceRoleMessage value)?  subsurface,}){
final _that = this;
switch (_that) {
case SubsurfaceRoleMessage() when subsurface != null:
return subsurface(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( SurfaceId parent, @OffsetConverter()  Offset position)?  subsurface,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SubsurfaceRoleMessage() when subsurface != null:
return subsurface(_that.parent,_that.position);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( SurfaceId parent, @OffsetConverter()  Offset position)  subsurface,}) {final _that = this;
switch (_that) {
case SubsurfaceRoleMessage():
return subsurface(_that.parent,_that.position);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( SurfaceId parent, @OffsetConverter()  Offset position)?  subsurface,}) {final _that = this;
switch (_that) {
case SubsurfaceRoleMessage() when subsurface != null:
return subsurface(_that.parent,_that.position);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class SubsurfaceRoleMessage implements SurfaceRoleMessage {
  const SubsurfaceRoleMessage({required this.parent, @OffsetConverter() required this.position});
  factory SubsurfaceRoleMessage.fromJson(Map<String, dynamic> json) => _$SubsurfaceRoleMessageFromJson(json);

@override final  SurfaceId parent;
@override@OffsetConverter() final  Offset position;

/// Create a copy of SurfaceRoleMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubsurfaceRoleMessageCopyWith<SubsurfaceRoleMessage> get copyWith => _$SubsurfaceRoleMessageCopyWithImpl<SubsurfaceRoleMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubsurfaceRoleMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubsurfaceRoleMessage&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.position, position) || other.position == position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,parent,position);

@override
String toString() {
  return 'SurfaceRoleMessage.subsurface(parent: $parent, position: $position)';
}


}

/// @nodoc
abstract mixin class $SubsurfaceRoleMessageCopyWith<$Res> implements $SurfaceRoleMessageCopyWith<$Res> {
  factory $SubsurfaceRoleMessageCopyWith(SubsurfaceRoleMessage value, $Res Function(SubsurfaceRoleMessage) _then) = _$SubsurfaceRoleMessageCopyWithImpl;
@override @useResult
$Res call({
 SurfaceId parent,@OffsetConverter() Offset position
});




}
/// @nodoc
class _$SubsurfaceRoleMessageCopyWithImpl<$Res>
    implements $SubsurfaceRoleMessageCopyWith<$Res> {
  _$SubsurfaceRoleMessageCopyWithImpl(this._self, this._then);

  final SubsurfaceRoleMessage _self;
  final $Res Function(SubsurfaceRoleMessage) _then;

/// Create a copy of SurfaceRoleMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? parent = null,Object? position = null,}) {
  return _then(SubsurfaceRoleMessage(
parent: null == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as SurfaceId,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Offset,
  ));
}


}

// dart format on

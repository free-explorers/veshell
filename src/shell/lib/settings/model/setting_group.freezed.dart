// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'setting_group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SettingGroup {

 String get name; String? get description; Map<String, SettingDefinition> get children; IconData? get icon;
/// Create a copy of SettingGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingGroupCopyWith<SettingGroup> get copyWith => _$SettingGroupCopyWithImpl<SettingGroup>(this as SettingGroup, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingGroup&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.children, children)&&(identical(other.icon, icon) || other.icon == icon));
}


@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(children),icon);

@override
String toString() {
  return 'SettingGroup(name: $name, description: $description, children: $children, icon: $icon)';
}


}

/// @nodoc
abstract mixin class $SettingGroupCopyWith<$Res>  {
  factory $SettingGroupCopyWith(SettingGroup value, $Res Function(SettingGroup) _then) = _$SettingGroupCopyWithImpl;
@useResult
$Res call({
 String name, String? description, Map<String, SettingDefinition> children, IconData? icon
});




}
/// @nodoc
class _$SettingGroupCopyWithImpl<$Res>
    implements $SettingGroupCopyWith<$Res> {
  _$SettingGroupCopyWithImpl(this._self, this._then);

  final SettingGroup _self;
  final $Res Function(SettingGroup) _then;

/// Create a copy of SettingGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = freezed,Object? children = null,Object? icon = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,children: null == children ? _self.children : children // ignore: cast_nullable_to_non_nullable
as Map<String, SettingDefinition>,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as IconData?,
  ));
}

}


/// Adds pattern-matching-related methods to [SettingGroup].
extension SettingGroupPatterns on SettingGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettingGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettingGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettingGroup value)  $default,){
final _that = this;
switch (_that) {
case _SettingGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettingGroup value)?  $default,){
final _that = this;
switch (_that) {
case _SettingGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? description,  Map<String, SettingDefinition> children,  IconData? icon)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingGroup() when $default != null:
return $default(_that.name,_that.description,_that.children,_that.icon);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? description,  Map<String, SettingDefinition> children,  IconData? icon)  $default,) {final _that = this;
switch (_that) {
case _SettingGroup():
return $default(_that.name,_that.description,_that.children,_that.icon);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? description,  Map<String, SettingDefinition> children,  IconData? icon)?  $default,) {final _that = this;
switch (_that) {
case _SettingGroup() when $default != null:
return $default(_that.name,_that.description,_that.children,_that.icon);case _:
  return null;

}
}

}

/// @nodoc


class _SettingGroup extends SettingGroup {
  const _SettingGroup({required this.name, required this.description, required final  Map<String, SettingDefinition> children, this.icon}): _children = children,super._();
  

@override final  String name;
@override final  String? description;
 final  Map<String, SettingDefinition> _children;
@override Map<String, SettingDefinition> get children {
  if (_children is EqualUnmodifiableMapView) return _children;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_children);
}

@override final  IconData? icon;

/// Create a copy of SettingGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingGroupCopyWith<_SettingGroup> get copyWith => __$SettingGroupCopyWithImpl<_SettingGroup>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingGroup&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._children, _children)&&(identical(other.icon, icon) || other.icon == icon));
}


@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(_children),icon);

@override
String toString() {
  return 'SettingGroup(name: $name, description: $description, children: $children, icon: $icon)';
}


}

/// @nodoc
abstract mixin class _$SettingGroupCopyWith<$Res> implements $SettingGroupCopyWith<$Res> {
  factory _$SettingGroupCopyWith(_SettingGroup value, $Res Function(_SettingGroup) _then) = __$SettingGroupCopyWithImpl;
@override @useResult
$Res call({
 String name, String? description, Map<String, SettingDefinition> children, IconData? icon
});




}
/// @nodoc
class __$SettingGroupCopyWithImpl<$Res>
    implements _$SettingGroupCopyWith<$Res> {
  __$SettingGroupCopyWithImpl(this._self, this._then);

  final _SettingGroup _self;
  final $Res Function(_SettingGroup) _then;

/// Create a copy of SettingGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = freezed,Object? children = null,Object? icon = freezed,}) {
  return _then(_SettingGroup(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,children: null == children ? _self._children : children // ignore: cast_nullable_to_non_nullable
as Map<String, SettingDefinition>,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as IconData?,
  ));
}


}

// dart format on

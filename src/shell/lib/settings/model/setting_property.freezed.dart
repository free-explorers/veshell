// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'setting_property.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SettingProperty<T> {

 String get name; String get description; JsonConverter<T, dynamic>? get converter; String? get key; Widget Function(BuildContext context, String path, SettingProperty<T> property)? get buildSearchResult;
/// Create a copy of SettingProperty
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingPropertyCopyWith<T, SettingProperty<T>> get copyWith => _$SettingPropertyCopyWithImpl<T, SettingProperty<T>>(this as SettingProperty<T>, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingProperty<T>&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.converter, converter) || other.converter == converter)&&(identical(other.key, key) || other.key == key)&&(identical(other.buildSearchResult, buildSearchResult) || other.buildSearchResult == buildSearchResult));
}


@override
int get hashCode => Object.hash(runtimeType,name,description,converter,key,buildSearchResult);

@override
String toString() {
  return 'SettingProperty<$T>(name: $name, description: $description, converter: $converter, key: $key, buildSearchResult: $buildSearchResult)';
}


}

/// @nodoc
abstract mixin class $SettingPropertyCopyWith<T,$Res>  {
  factory $SettingPropertyCopyWith(SettingProperty<T> value, $Res Function(SettingProperty<T>) _then) = _$SettingPropertyCopyWithImpl;
@useResult
$Res call({
 String name, String description, JsonConverter<T, dynamic>? converter, String? key, Widget Function(BuildContext context, String path, SettingProperty<T> property)? buildSearchResult
});




}
/// @nodoc
class _$SettingPropertyCopyWithImpl<T,$Res>
    implements $SettingPropertyCopyWith<T, $Res> {
  _$SettingPropertyCopyWithImpl(this._self, this._then);

  final SettingProperty<T> _self;
  final $Res Function(SettingProperty<T>) _then;

/// Create a copy of SettingProperty
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? converter = freezed,Object? key = freezed,Object? buildSearchResult = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,converter: freezed == converter ? _self.converter : converter // ignore: cast_nullable_to_non_nullable
as JsonConverter<T, dynamic>?,key: freezed == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String?,buildSearchResult: freezed == buildSearchResult ? _self.buildSearchResult : buildSearchResult // ignore: cast_nullable_to_non_nullable
as Widget Function(BuildContext context, String path, SettingProperty<T> property)?,
  ));
}

}


/// Adds pattern-matching-related methods to [SettingProperty].
extension SettingPropertyPatterns<T> on SettingProperty<T> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettingProperty<T> value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettingProperty() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettingProperty<T> value)  $default,){
final _that = this;
switch (_that) {
case _SettingProperty():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettingProperty<T> value)?  $default,){
final _that = this;
switch (_that) {
case _SettingProperty() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  JsonConverter<T, dynamic>? converter,  String? key,  Widget Function(BuildContext context, String path, SettingProperty<T> property)? buildSearchResult)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingProperty() when $default != null:
return $default(_that.name,_that.description,_that.converter,_that.key,_that.buildSearchResult);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  JsonConverter<T, dynamic>? converter,  String? key,  Widget Function(BuildContext context, String path, SettingProperty<T> property)? buildSearchResult)  $default,) {final _that = this;
switch (_that) {
case _SettingProperty():
return $default(_that.name,_that.description,_that.converter,_that.key,_that.buildSearchResult);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  JsonConverter<T, dynamic>? converter,  String? key,  Widget Function(BuildContext context, String path, SettingProperty<T> property)? buildSearchResult)?  $default,) {final _that = this;
switch (_that) {
case _SettingProperty() when $default != null:
return $default(_that.name,_that.description,_that.converter,_that.key,_that.buildSearchResult);case _:
  return null;

}
}

}

/// @nodoc


class _SettingProperty<T> extends SettingProperty<T> {
  const _SettingProperty({required this.name, required this.description, this.converter, this.key, this.buildSearchResult}): super._();
  

@override final  String name;
@override final  String description;
@override final  JsonConverter<T, dynamic>? converter;
@override final  String? key;
@override final  Widget Function(BuildContext context, String path, SettingProperty<T> property)? buildSearchResult;

/// Create a copy of SettingProperty
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingPropertyCopyWith<T, _SettingProperty<T>> get copyWith => __$SettingPropertyCopyWithImpl<T, _SettingProperty<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingProperty<T>&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.converter, converter) || other.converter == converter)&&(identical(other.key, key) || other.key == key)&&(identical(other.buildSearchResult, buildSearchResult) || other.buildSearchResult == buildSearchResult));
}


@override
int get hashCode => Object.hash(runtimeType,name,description,converter,key,buildSearchResult);

@override
String toString() {
  return 'SettingProperty<$T>(name: $name, description: $description, converter: $converter, key: $key, buildSearchResult: $buildSearchResult)';
}


}

/// @nodoc
abstract mixin class _$SettingPropertyCopyWith<T,$Res> implements $SettingPropertyCopyWith<T, $Res> {
  factory _$SettingPropertyCopyWith(_SettingProperty<T> value, $Res Function(_SettingProperty<T>) _then) = __$SettingPropertyCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, JsonConverter<T, dynamic>? converter, String? key, Widget Function(BuildContext context, String path, SettingProperty<T> property)? buildSearchResult
});




}
/// @nodoc
class __$SettingPropertyCopyWithImpl<T,$Res>
    implements _$SettingPropertyCopyWith<T, $Res> {
  __$SettingPropertyCopyWithImpl(this._self, this._then);

  final _SettingProperty<T> _self;
  final $Res Function(_SettingProperty<T>) _then;

/// Create a copy of SettingProperty
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? converter = freezed,Object? key = freezed,Object? buildSearchResult = freezed,}) {
  return _then(_SettingProperty<T>(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,converter: freezed == converter ? _self.converter : converter // ignore: cast_nullable_to_non_nullable
as JsonConverter<T, dynamic>?,key: freezed == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String?,buildSearchResult: freezed == buildSearchResult ? _self.buildSearchResult : buildSearchResult // ignore: cast_nullable_to_non_nullable
as Widget Function(BuildContext context, String path, SettingProperty<T> property)?,
  ));
}


}

// dart format on

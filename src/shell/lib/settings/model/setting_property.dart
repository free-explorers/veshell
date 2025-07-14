import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/settings/model/setting_definition.dart';
import 'package:shell/settings/widget/expandable_search_result.dart';
import 'package:shell/settings/widget/primitive/setting_property_bool_editor.dart';
import 'package:shell/settings/widget/primitive/setting_property_color_editor.dart';
import 'package:shell/settings/widget/primitive/setting_property_double_editor.dart';
import 'package:shell/settings/widget/primitive/setting_property_int_editor.dart';
import 'package:shell/settings/widget/primitive/setting_property_string_editor.dart';

part 'setting_property.freezed.dart';

@freezed
abstract class SettingProperty<T>
    with _$SettingProperty<T>
    implements SettingDefinition {
  const factory SettingProperty({
    required String name,
    required String description,
    JsonConverter<T, dynamic>? converter,
    String? key,
    Widget Function(
      BuildContext context,
      String path,
      SettingProperty<T> property,
    )? buildSearchResult,
  }) = _SettingProperty;
  const SettingProperty._();

  T castValue(dynamic val) =>
      converter != null ? converter!.fromJson(val) : val as T;

  dynamic serializeValue(T val) =>
      converter != null ? converter!.toJson(val) : val;

  Widget build(BuildContext context, String path) {
    return buildSearchResult?.call(context, path, this) ??
        defaultBuildSearchResult<T>(context, path, this);
  }
}

Widget defaultBuildSearchResult<T>(
  BuildContext context,
  String path,
  SettingProperty<T> property,
) {
  return switch (property) {
    // primitive types
    SettingProperty<String>() => ExpandableSearchResult(
        path: path,
        property: property,
        buildValue: (context, value, {required isExpanded}) => Text('$value'),
        buildEditor: (context, {required isExpanded}) =>
            SettingPropertyStringEditor(
          path: path,
          property: property as SettingProperty<String>,
        ),
      ),
    SettingProperty<bool>() => SettingPropertyBoolEditor(
        path: path,
        property: property as SettingProperty<bool>,
      ),
    SettingProperty<int>() => SettingPropertyIntEditor(
        path: path,
        property: property as SettingProperty<int>,
      ),
    SettingProperty<double>() => ExpandableSearchResult(
        path: path,
        property: property,
        buildValue: (context, value, {required isExpanded}) => Text('$value'),
        buildEditor: (context, {required isExpanded}) =>
            SettingPropertyDoubleEditor(
          path: path,
          property: property as SettingProperty<double>,
        ),
      ),
    SettingProperty<Color>() => ExpandableSearchResult(
        path: path,
        property: property,
        buildValue: (context, value, {required isExpanded}) => ColorIndicator(
          color: (property as SettingProperty<Color>).castValue(value),
        ),
        buildEditor: (context, {required isExpanded}) =>
            SettingPropertyColorEditor(
          path: path,
          property: property as SettingProperty<Color>,
        ),
      ),
    SettingProperty<T>() => throw UnimplementedError(),
  };
}

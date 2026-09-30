import 'package:shell/settings/model/setting_definition.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';

/// Whether [definition] matches [searchText] at [path].
///
/// An empty [searchText] matches everything; a group matches when any of its
/// descendants does.
bool searchSetting(
  String searchText,
  SettingDefinition definition,
  String path,
) {
  if (searchText == '') return true;
  if (definition is SettingGroup) {
    return definition.children.entries.any(
      (entry) => searchSetting(searchText, entry.value, '$path.${entry.key}'),
    );
  }
  if (definition is SettingProperty) {
    return '${definition.name}.${definition.description}'
        .toLowerCase()
        .contains(searchText.toLowerCase());
  }
  return false;
}

/// The paths of the top-level setting categories that match [searchText], in
/// display order. Keyboard navigation walks these categories.
List<String> collectSettingCategoryPathList(
  Map<String, SettingGroup> settingMap,
  String searchText,
) {
  return [
    for (final entry in settingMap.entries)
      if (searchSetting(searchText, entry.value, entry.key)) entry.key,
  ];
}

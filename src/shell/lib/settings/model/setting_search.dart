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

/// The paths of the leaf properties under [settingMap] that match [searchText],
/// in the order the settings tree renders them.
List<String> collectSettingLeafPathList(
  Map<String, SettingGroup> settingMap,
  String searchText,
) {
  final pathList = <String>[];
  for (final entry in settingMap.entries) {
    _collectLeaves(entry.value, entry.key, searchText, pathList);
  }
  return pathList;
}

void _collectLeaves(
  SettingDefinition definition,
  String path,
  String searchText,
  List<String> pathList,
) {
  if (!searchSetting(searchText, definition, path)) {
    return;
  }
  if (definition is SettingGroup) {
    for (final entry in definition.children.entries) {
      _collectLeaves(entry.value, '$path.${entry.key}', searchText, pathList);
    }
  } else if (definition is SettingProperty) {
    pathList.add(path);
  }
}

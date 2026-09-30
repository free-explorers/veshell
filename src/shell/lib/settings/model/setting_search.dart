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

/// A visible row in the settings result: a group header or a leaf property.
typedef SettingRow = ({String path, bool isGroup});

/// The visible settings rows in render order, given the expansion state.
///
/// A group contributes its header and, when expanded (or while filtering, which
/// force-opens everything), its children recursively. Keyboard navigation walks
/// this list, so moving down from an open category lands on its children.
List<SettingRow> collectSettingVisibleRowList(
  Map<String, SettingGroup> settingMap,
  String searchText,
  Set<String> expandedPathSet,
) {
  final rowList = <SettingRow>[];
  for (final entry in settingMap.entries) {
    _collectVisibleRows(
      entry.value,
      entry.key,
      searchText,
      expandedPathSet,
      rowList,
    );
  }
  return rowList;
}

void _collectVisibleRows(
  SettingDefinition definition,
  String path,
  String searchText,
  Set<String> expandedPathSet,
  List<SettingRow> rowList,
) {
  if (!searchSetting(searchText, definition, path)) {
    return;
  }
  if (definition is SettingGroup) {
    rowList.add((path: path, isGroup: true));
    if (searchText != '' || expandedPathSet.contains(path)) {
      for (final entry in definition.children.entries) {
        _collectVisibleRows(
          entry.value,
          '$path.${entry.key}',
          searchText,
          expandedPathSet,
          rowList,
        );
      }
    }
  } else if (definition is SettingProperty) {
    rowList.add((path: path, isGroup: false));
  }
}

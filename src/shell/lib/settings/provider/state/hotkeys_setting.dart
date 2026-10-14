import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/provider/util/setting_definition_by_path.dart';

part 'hotkeys_setting.g.dart';

/// Action ids that were renamed when navigation was standardised.
///
/// The new id is the key; the value is the pre-standardisation id. A user's
/// existing override is read through this fallback so a rename never silently
/// drops a binding.
const _legacyActionIds = <String, String>{
  'navigation.up': 'screen.focusWorkspaceAbove',
  'navigation.down': 'screen.focusWorkspaceBelow',
  'navigation.left': 'workspace.focusLeftTileable',
  'navigation.right': 'workspace.focusRightTileable',
  'navigation.moveUp': 'screen.reorderWorkspaceAbove',
  'navigation.moveDown': 'screen.reorderWorkspaceBelow',
  'navigation.moveLeft': 'workspace.reorderLeftTileable',
  'navigation.moveRight': 'workspace.reorderRightTileable',
  'navigation.close': 'workspace.closeTileable',
};

@riverpod
Map<String, List<LogicalKeySet>> hotkeysSetting(Ref ref) {
  const path = 'keyboard.hotkeys';
  const fallback = <String, List<LogicalKeySet>>{};

  final group = ref.watch(settingDefinitionByPathProvider(path));
  if (group == null || group is! SettingGroup) {
    return fallback;
  }
  final hotkeys = <String, List<LogicalKeySet>>{};
  for (final entry in group.children.entries) {
    final actionId = entry.key;
    final property = entry.value;
    if (property is! SettingProperty<List<LogicalKeySet>>) {
      continue;
    }
    var jsonValue = ref.watch(jsonValueByPathProvider('$path.$actionId'));
    // Fall back to the pre-rename key when the new one was never written.
    final legacyId = _legacyActionIds[actionId];
    jsonValue ??= legacyId == null
        ? null
        : ref.watch(jsonValueByPathProvider('$path.$legacyId'));
    final hotkeyList = property.tryCastValue(jsonValue);
    // A missing, malformed or empty value must never become an activator:
    // `LogicalKeySet.fromSet({})` accepts every key event.
    if (hotkeyList == null || hotkeyList.isEmpty) {
      continue;
    }
    hotkeys[actionId] = hotkeyList;
  }
  return hotkeys;
}

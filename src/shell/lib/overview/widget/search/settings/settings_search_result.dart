import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/model/setting_search.dart';
import 'package:shell/settings/provider/settings_properties.dart';

/// The settings tree for the given searchText, navigable by selection index.
class SettingsSearchResult extends HookConsumerWidget {
  ///
  const SettingsSearchResult({
    required this.searchText,
    this.selectedIndex,
    super.key,
  });
  final String searchText;
  final int? selectedIndex;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingMap = ref.watch(settingsPropertiesProvider);
    final leafPathList = collectSettingLeafPathList(settingMap, searchText);
    final index = selectedIndex;
    final selectedLeafPath =
        index != null && index >= 0 && index < leafPathList.length
        ? leafPathList[index]
        : null;
    final selectedLeafKey = useMemoized(GlobalKey.new);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final leafContext = selectedLeafKey.currentContext;
        if (leafContext == null) return;
        Scrollable.ensureVisible(
          leafContext,
          alignment: 0.3,
          duration: const Duration(milliseconds: 120),
        );
      });
      return null;
    }, [selectedIndex]);

    return CustomScrollView(
      slivers: settingMap.entries.map((entry) {
        return SettingGroupListSliver(
          searchText: searchText,
          settingGroup: entry.value,
          path: entry.key,
          selectedLeafPath: selectedLeafPath,
          selectedLeafKey: selectedLeafKey,
        );
      }).toList(),
    );
  }
}

class SettingGroupListSliver extends HookWidget {
  const SettingGroupListSliver({
    required this.searchText,
    required this.settingGroup,
    required this.path,
    this.selectedLeafPath,
    this.selectedLeafKey,
    super.key,
  });

  final String searchText;
  final String path;
  final SettingGroup settingGroup;
  final String? selectedLeafPath;
  final Key? selectedLeafKey;

  @override
  Widget build(BuildContext context) {
    final expanded = useState(searchText != '');
    useEffect(() {
      if (searchText != '') {
        expanded.value = true;
      }
      return null;
    }, [searchText]);
    // Force a group open while it contains the keyboard selection, so a leaf
    // reached with Super+W/S is always visible.
    final selectedPath = selectedLeafPath;
    final isOnSelectedPath =
        selectedPath != null &&
        (selectedPath == path || selectedPath.startsWith('$path.'));
    final isExpanded = expanded.value || isOnSelectedPath;
    if (!searchSetting(searchText, settingGroup, path)) {
      return const SliverToBoxAdapter();
    } else {
      return SliverMainAxisGroup(
        slivers: [
          SliverAppBar(
            backgroundColor: Color.lerp(
              Theme.of(context).colorScheme.surface,
              Colors.black,
              0.2 * (path.split('.').length - 1),
            ),
            toolbarHeight: 72,
            flexibleSpace: ListTile(
              minTileHeight: 72,
              onTap: () {
                expanded.value = !expanded.value;
              },
              leading: settingGroup.icon != null
                  ? Icon(settingGroup.icon)
                  : null,
              title: Text(
                settingGroup.name,
                style: settingGroup.description == null
                    ? Theme.of(context).textTheme.titleLarge
                    : null,
              ),
              subtitle: settingGroup.description != null
                  ? Text(settingGroup.description!)
                  : null,
              trailing: isExpanded
                  ? const Icon(MdiIcons.chevronUp)
                  : const Icon(MdiIcons.chevronDown),
            ),
            pinned: true,
            floating: true,
            surfaceTintColor: Colors.transparent,
          ),
          if (isExpanded)
            DecoratedSliver(
              decoration: BoxDecoration(
                color: Color.lerp(
                  Theme.of(context).colorScheme.surface,
                  Colors.black,
                  0.2 * path.split('.').length,
                ),
              ),
              sliver: SliverMainAxisGroup(
                slivers: [
                  ...settingGroup.children.entries.map((entry) {
                    if (entry.value is SettingGroup) {
                      return SettingGroupListSliver(
                        searchText: searchText,
                        settingGroup: entry.value as SettingGroup,
                        path: '$path.${entry.key}',
                        selectedLeafPath: selectedLeafPath,
                        selectedLeafKey: selectedLeafKey,
                      );
                    } else {
                      if (!searchSetting(
                        searchText,
                        entry.value,
                        '$path.${entry.key}',
                      )) {
                        return const SliverToBoxAdapter();
                      }
                      return SettingPropertySliver(
                        property: entry.value as SettingProperty,
                        path: '$path.${entry.key}',
                        isSelected: '$path.${entry.key}' == selectedLeafPath,
                        selectedKey: selectedLeafKey,
                      );
                    }
                  }),
                ],
              ),
            ),
        ],
      );
    }
  }
}

class SettingPropertySliver<T> extends StatelessWidget {
  const SettingPropertySliver({
    required this.property,
    required this.path,
    this.isSelected = false,
    this.selectedKey,
    super.key,
  });

  final String path;
  final SettingProperty<T> property;
  final bool isSelected;
  final Key? selectedKey;

  @override
  Widget build(BuildContext context) {
    final content = property.build(context, path);
    return SliverToBoxAdapter(
      child: isSelected
          ? DecoratedBox(
              key: selectedKey,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: content,
            )
          : content,
    );
  }
}
/* 
class SettingPropertyValue<T> extends HookConsumerWidget {
  const SettingPropertyValue({
    required this.path,
    required this.property,
    super.key,
  });
  final String path;
  final SettingProperty<T> property;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final val = ref.watch(jsonValueByPathProvider(path));

    return switch (property) {
      SettingProperty<String>() => Text('$val'),
      SettingProperty<double>() => Text('$val'),
      SettingProperty<bool>() => Text('$val'),
      SettingProperty<Color>() => ColorIndicator(
          color: (property as SettingProperty<Color>).castValue(val),
        ),
      SettingProperty<LogicalKeySet>() => HotkeyViewer(
          hotkey:
              (property as SettingProperty<LogicalKeySet>).castValue(val ?? ''),
        ),
      SettingProperty<MonitorResolution>() =>
        MonitorResolutionValue(path: path),
      SettingProperty<MonitorRefreshRate>() =>
        MonitorRefreshRateValue(path: path),
      SettingProperty<T>() => throw UnimplementedError(),
    };
  }
}

class SettingPropertyEditor<T> extends HookConsumerWidget {
  const SettingPropertyEditor({
    required this.path,
    required this.property,
    super.key,
  });
  final String path;
  final SettingProperty<T> property;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void onValueChanged(dynamic value) {}
    return switch (property) {
      SettingProperty<String>() => SettingPropertyStringEditor(
          path: path,
          property: property as SettingProperty<String>,
          onChanged: onValueChanged,
        ),
      SettingProperty<Color>() => SettingPropertyColorEditor(
          path: path,
          property: property as SettingProperty<Color>,
          onChanged: onValueChanged,
        ),
      SettingProperty<LogicalKeySet>() => SettingPropertyHotkeyEditor(
          path: path,
          property: property as SettingProperty<LogicalKeySet>,
          onChanged: onValueChanged,
        ),
      SettingProperty<MonitorResolution>() => MonitorResolutionEditor(
          path: path,
          property: property as SettingProperty<MonitorResolution>,
          onChanged: onValueChanged,
        ),
      SettingProperty<MonitorRefreshRate>() => MonitorRefreshRateEditor(
          path: path,
          property: property as SettingProperty<MonitorRefreshRate>,
          onChanged: onValueChanged,
        ),
      SettingProperty<T>() => throw UnimplementedError(),
    };
  }
} */

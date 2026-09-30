import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/model/setting_search.dart';
import 'package:shell/settings/provider/setting_group_expanded.dart';
import 'package:shell/settings/provider/settings_properties.dart';

/// The settings tree for the given searchText, navigable by category index.
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
    final categoryPathList = collectSettingCategoryPathList(
      settingMap,
      searchText,
    );
    final index = selectedIndex;
    final selectedCategoryPath =
        index != null && index >= 0 && index < categoryPathList.length
        ? categoryPathList[index]
        : null;
    final selectedCategoryKey = useMemoized(GlobalKey.new);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final categoryContext = selectedCategoryKey.currentContext;
        if (categoryContext == null) return;
        Scrollable.ensureVisible(
          categoryContext,
          alignment: 0.2,
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
          selectedCategoryPath: selectedCategoryPath,
          selectedCategoryKey: selectedCategoryKey,
        );
      }).toList(),
    );
  }
}

class SettingGroupListSliver extends HookConsumerWidget {
  const SettingGroupListSliver({
    required this.searchText,
    required this.settingGroup,
    required this.path,
    this.selectedCategoryPath,
    this.selectedCategoryKey,
    super.key,
  });

  final String searchText;
  final String path;
  final SettingGroup settingGroup;
  final String? selectedCategoryPath;
  final Key? selectedCategoryKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!searchSetting(searchText, settingGroup, path)) {
      return const SliverToBoxAdapter();
    }
    // A search query force-opens every group so the matches are visible;
    // otherwise Super+D (or a click) controls the expansion.
    final isExpanded =
        searchText != '' || ref.watch(settingGroupExpandedProvider(path));
    final isSelected = path == selectedCategoryPath;
    final colorScheme = Theme.of(context).colorScheme;
    return SliverMainAxisGroup(
      slivers: [
        SliverAppBar(
          backgroundColor: isSelected
              ? colorScheme.primaryContainer
              : Color.lerp(
                  colorScheme.surface,
                  Colors.black,
                  0.2 * (path.split('.').length - 1),
                ),
          toolbarHeight: 72,
          flexibleSpace: ListTile(
            key: isSelected ? selectedCategoryKey : null,
            minTileHeight: 72,
            onTap: () =>
                ref.read(settingGroupExpandedProvider(path).notifier).toggle(),
            leading: settingGroup.icon != null ? Icon(settingGroup.icon) : null,
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
                colorScheme.surface,
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
                      selectedCategoryPath: selectedCategoryPath,
                      selectedCategoryKey: selectedCategoryKey,
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

class SettingPropertySliver<T> extends StatelessWidget {
  const SettingPropertySliver({
    required this.property,
    required this.path,
    super.key,
  });

  final String path;
  final SettingProperty<T> property;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: property.build(context, path));
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

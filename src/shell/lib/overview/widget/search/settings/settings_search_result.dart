import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/overview/widget/search/settings/keyboard/setting_property_hotkey_editor.dart';
import 'package:shell/overview/widget/search/settings/monitor/monitor_refresh_rate_value.dart';
import 'package:shell/overview/widget/search/settings/monitor/monitor_resolution_editor.dart';
import 'package:shell/overview/widget/search/settings/monitor/monitor_resolution_value.dart';
import 'package:shell/overview/widget/search/settings/primitive/setting_property_color_editor.dart';
import 'package:shell/overview/widget/search/settings/primitive/setting_property_string_editor.dart';
import 'package:shell/settings/model/setting_definition.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/widget/expandable_container.dart';
import 'package:shell/shared/widget/hotkey_viewer.dart';

/// List of applications for the given searchText
class SettingsSearchResult extends HookConsumerWidget {
  ///
  const SettingsSearchResult({required this.searchText, super.key});
  final String searchText;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingMap = ref.watch(settingsPropertiesProvider);

    return CustomScrollView(
      slivers: settingMap.entries.map((entry) {
        return SettingGroupListSliver(
          searchText: searchText,
          settingGroup: entry.value,
          path: entry.key,
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
    super.key,
  });

  final String searchText;
  final String path;
  final SettingGroup settingGroup;

  @override
  Widget build(BuildContext context) {
    final expanded = useState(searchText != '');
    useEffect(
      () {
        if (searchText != '') {
          expanded.value = true;
        }
        return null;
      },
      [searchText],
    );
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
              leading:
                  settingGroup.icon != null ? Icon(settingGroup.icon) : null,
              title: Text(
                settingGroup.name,
                style: settingGroup.description == null
                    ? Theme.of(context).textTheme.titleLarge
                    : null,
              ),
              subtitle: settingGroup.description != null
                  ? Text(
                      settingGroup.description!,
                    )
                  : null,
              trailing: expanded.value
                  ? const Icon(MdiIcons.chevronUp)
                  : const Icon(MdiIcons.chevronDown),
            ),
            pinned: true,
            floating: true,
            surfaceTintColor: Colors.transparent,
          ),
          if (expanded.value)
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
    return SliverToBoxAdapter(
      child: ExpandableContainer(
        builder: (BuildContext context, {required bool isExpanded}) {
          final tile = ListTile(
            onTap: isExpanded
                ? null
                : () {
                    ExpandableContainer.of(context).toggle();
                  },
            title: Text(property.name),
            subtitle: Text(property.description),
            trailing: SettingPropertyValue(path: path, property: property),
          );

          return Card(
            color: isExpanded ? null : Colors.transparent,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                tile,
                if (isExpanded)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child:
                          SettingPropertyEditor(path: path, property: property),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

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
      SettingProperty<Color>() => ColorIndicator(
          color: (property as SettingProperty<Color>).castValue(val!),
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
      SettingProperty<T>() => throw UnimplementedError(),
    };
  }
}

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

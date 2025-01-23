import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
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
    final expanded = useState(false);
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
            leading: settingGroup.icon != null ? Icon(settingGroup.icon) : null,
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
    if (path.startsWith('keyboard.hotkeys')) {
      return HotkeyViewer(
        hotkey: val ?? '',
      );
    }
    return switch (property) {
      SettingProperty<String>() => Text('$val'),
      SettingProperty<Color>() => ColorIndicator(
          color: (property as SettingProperty<Color>).castValue(val!),
        ),
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
    final val = ref.watch(jsonValueByPathProvider(path));
    if (path.startsWith('keyboard.hotkeys')) {
      return HotkeyViewer(
        hotkey: val ?? '',
      );
    }
    return switch (property) {
      SettingProperty<String>() => SettingPropertyStringEditor(
          initialValue: val ?? '',
          onChanged: (newValue) {
            print('newValue: $newValue');
            ref.read(settingsPropertiesProvider.notifier).updateProperty(
                  path,
                  newValue,
                );
          },
        ),
      SettingProperty<Color>() => SettingPropertyColorEditor(
          initialValue:
              (property as SettingProperty<Color>).castValue(val ?? ''),
          onChanged: (newValue) {
            print('newColor: $newValue');
            ref.read(settingsPropertiesProvider.notifier).updateProperty(
                  path,
                  (property as SettingProperty<Color>).serializeValue(newValue),
                );
          },
        ),
      SettingProperty<T>() => throw UnimplementedError(),
    };
  }
}

class SettingPropertyStringEditor extends HookConsumerWidget {
  const SettingPropertyStringEditor({
    required this.initialValue,
    required this.onChanged,
    super.key,
  });
  final String initialValue;
  final void Function(String newValue) onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController(text: initialValue);
    return TextField(
      controller: controller,
      autofocus: true,
      decoration: const InputDecoration(
        filled: true,
      ),
      onSubmitted: onChanged,
    );
  }
}

class SettingPropertyColorEditor extends HookConsumerWidget {
  const SettingPropertyColorEditor({
    required this.initialValue,
    required this.onChanged,
    super.key,
  });
  final Color initialValue;
  final void Function(Color newValue) onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatedBy = useState<String?>(null);

    return Row(
      spacing: 16,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: ColorWheelPicker(
            color: initialValue,
            onChanged: (color) {
              onChanged(color);
              updatedBy.value = 'wheel';
            },
            onWheel: (value) {},
            shouldUpdate: updatedBy.value != 'wheel',
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Row(
              spacing: 8,
              children: [
                const Color(0xFF006888),
                const Color(0xFFB71C1C),
                const Color(0xFF2E7D32),
                const Color(0xFFC51162),
                const Color(0xFFD8DEE9),
              ]
                  .map(
                    (Color color) => ColorIndicator(
                      color: color,
                      onSelect: () {
                        onChanged(color);
                        updatedBy.value = 'indicator';
                      },
                      isSelected: initialValue == color,
                    ),
                  )
                  .toList(),
            ),
            ColorCodeField(
              color: initialValue,
              onColorChanged: (color) {
                onChanged(color);
                updatedBy.value = 'code';
              },
              onEditFocused: (bool) {},
              requestFocus: false,
              focusedEditHasNoColor: false,
              colorCodeHasColor: true,
              shouldUpdate: updatedBy.value != 'code',
            ),
          ],
        ),
      ],
    );
  }
}

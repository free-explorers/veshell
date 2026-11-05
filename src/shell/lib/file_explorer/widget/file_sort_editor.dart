import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/file_explorer/model/file_explorer_settings.dart';
import 'package:shell/file_explorer/provider/file_explorer_settings.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/shared/widget/expandable_container.dart';
import 'package:shell/shared/widget/shell_icon.dart';

/// The localized label of a sort key.
String fileSortKeyLabel(AppLocalizations l10n, FileSortKey key) =>
    switch (key) {
      FileSortKey.name => l10n.sortByName,
      FileSortKey.modified => l10n.sortByModified,
      FileSortKey.size => l10n.sortBySize,
      FileSortKey.type => l10n.sortByType,
    };

/// Trailing summary of the `files.sortBy` property.
class FileSortKeyValue extends ConsumerWidget {
  const FileSortKeyValue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortBy = ref.watch(
      fileExplorerSettingsProvider.select((settings) => settings.sortBy),
    );
    return Text(fileSortKeyLabel(context.l10n, sortBy));
  }
}

/// Picks the key the file explorer sorts by.
class FileSortKeyEditor extends ConsumerWidget
    implements SettingPropertyValueEditor<String> {
  const FileSortKeyEditor({
    required this.path,
    required this.property,
    super.key,
  });

  @override
  final String path;

  @override
  final SettingProperty<String> property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      fileExplorerSettingsProvider.select((settings) => settings.sortBy),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final key in FileSortKey.values)
          ListTile(
            title: Text(fileSortKeyLabel(context.l10n, key)),
            trailing: key == current ? const ShellIcon(MdiIcons.check) : null,
            onTap: () {
              updateFileExplorerSetting(ref, path, key);
              ExpandableContainer.of(context).toggle();
            },
          ),
      ],
    );
  }
}

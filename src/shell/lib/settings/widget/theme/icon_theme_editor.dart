import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/util/normalizing_svg_file_loader.dart';
import 'package:shell/application/widget/letter_app_icon.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/installed_icon_themes.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/provider/util/theme_detection.dart';
import 'package:shell/settings/widget/primitive/dropdown_setting_editor.dart';
import 'package:shell/shared/widget/expandable_container.dart';

/// Icon-theme picker: the installed XDG icon themes plus the built-in letter
/// placeholders.
///
/// Only installed themes are offered, so the common failure mode of a
/// hand-typed name that no longer exists cannot be selected from the UI. A
/// stale configured value stays visible so it can be corrected instead of
/// silently disappearing from the dropdown.
class IconThemeEditor extends HookConsumerWidget
    implements SettingPropertyValueEditor<String> {
  const IconThemeEditor({
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
    final raw = property.tryCastValue(ref.watch(jsonValueByPathProvider(path)));
    final stored = raw == null || raw.trim().isEmpty ? null : raw;
    final installed = ref.watch(installedIconThemeNamesProvider);
    final draft = useState<String?>(stored);
    useEffect(() {
      draft.value = stored;
      return null;
    }, [stored]);

    final themes = installed
        .where((theme) => !isLetterIconTheme(theme))
        .toList();
    if (stored != null &&
        stored.isNotEmpty &&
        !isLetterIconTheme(stored) &&
        !themes.contains(stored)) {
      themes.add(stored);
    }
    themes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return DropdownSettingEditor<String>(
      dropdownKey: ValueKey('${draft.value}|${themes.join(',')}'),
      value: draft.value,
      decoration: InputDecoration(filled: true, labelText: property.name),
      hint: Text(context.l10n.notSet),
      items: [
        DropdownMenuItem(
          value: letterIconThemeId,
          child: _ThemeLabel(
            icon: const LetterAppIcon(title: 'Ab'),
            label: context.l10n.letterIcons,
          ),
        ),
        for (final theme in themes)
          DropdownMenuItem(
            value: theme,
            child: _ThemeLabel(
              icon: IconThemePreview(theme: theme),
              label: theme,
            ),
          ),
      ],
      onChanged: (theme) {
        if (theme == null) return;
        draft.value = theme;
      },
      onConfirm: () {
        final theme = draft.value;
        if (theme == null) return;
        ref
            .read(settingsPropertiesProvider.notifier)
            .updateProperty(path, property.serializeValue(theme));
        ExpandableContainer.maybeOf(context)?.collapse();
      },
    );
  }
}

/// Trailing summary of the `theme.iconTheme` property.
class IconThemeValue extends ConsumerWidget {
  const IconThemeValue({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(jsonValueByPathProvider(path));
    if (value is! String || value.isEmpty) {
      return Text(context.l10n.notSet);
    }
    return isLetterIconTheme(value)
        ? _ThemeLabel(
            icon: const LetterAppIcon(title: 'Ab'),
            label: context.l10n.letterIcons,
            compact: true,
          )
        : _ThemeLabel(
            icon: IconThemePreview(theme: value),
            label: value,
            compact: true,
          );
  }
}

/// A theme name led by a sample icon drawn the way that theme would draw it.
class _ThemeLabel extends StatelessWidget {
  const _ThemeLabel({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final Widget icon;
  final String label;

  /// Size to the content instead of filling the dropdown row.
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
    spacing: 8,
    children: [
      SizedBox.square(dimension: 20, child: icon),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
    ],
  );
}

/// The `folder` icon of [theme], or an empty slot while it resolves or when
/// the theme has none.
class IconThemePreview extends ConsumerWidget {
  const IconThemePreview({required this.theme, super.key});

  final String theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(iconThemePreviewProvider(theme)).value;
    if (file == null) return const SizedBox.shrink();
    if (file.path.endsWith('.svg')) {
      return SvgPicture(NormalizingSvgFileLoader(file));
    }
    final pixels = (20 * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Image.file(file, cacheWidth: pixels);
  }
}

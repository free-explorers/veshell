import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/widget/primitive/dropdown_setting_editor.dart';
import 'package:shell/shared/widget/expandable_container.dart';

/// Only shipped catalogs, independent of the system's installed locales.
class VeshellLanguageEditor extends HookConsumerWidget {
  const VeshellLanguageEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(shellLocaleProvider);
    final matchesSystem = ref.watch(systemLanguageSupportedProvider);
    final selected = ref.watch(veshellFollowsSystemProvider)
        ? ''
        : locale.toLanguageTag();
    final draft = useState(selected);
    useEffect(() {
      draft.value = selected;
      return null;
    }, [selected, matchesSystem]);
    return DropdownSettingEditor<String>(
      dropdownKey: ValueKey('${draft.value}:$matchesSystem'),
      value: draft.value,
      decoration: InputDecoration(
        filled: true,
        labelText: context.l10n.veshellLanguage,
      ),
      items: [
        if (matchesSystem)
          DropdownMenuItem(value: '', child: Text(context.l10n.sameAsSystem)),
        for (final supported in AppLocalizations.supportedLocales)
          DropdownMenuItem(
            value: supported.toLanguageTag(),
            child: Text(lookupAppLocalizations(supported).languageAutonym),
          ),
      ],
      onChanged: (language) {
        if (language == null) return;
        draft.value = language;
      },
      onConfirm: () {
        final expandable = ExpandableContainer.maybeOf(context);
        try {
          ref
              .read(settingsPropertiesProvider.notifier)
              .updateProperty(
                'system.language',
                draft.value.isEmpty ? null : draft.value,
              );
          expandable?.collapse();
        } on Object catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.veshellLanguageSaveFailed)),
          );
        }
      },
    );
  }
}

class VeshellLanguageValue extends ConsumerWidget {
  const VeshellLanguageValue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
    ref.watch(veshellFollowsSystemProvider)
        ? context.l10n.sameAsSystem
        : ref.watch(shellLocalizationsProvider).languageAutonym,
  );
}

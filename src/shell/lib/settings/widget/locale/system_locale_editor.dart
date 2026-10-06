import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/model/system_locale.dart';
import 'package:shell/settings/provider/system_locale.dart';
import 'package:shell/settings/widget/primitive/dropdown_setting_editor.dart';
import 'package:shell/shared/widget/expandable_container.dart';

class SystemLocaleValue extends ConsumerWidget {
  const SystemLocaleValue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(systemLocaleProvider)
      .when(
        data: (values) => Text(
          values['LANG'] == null
              ? context.l10n.localeSystemDefault
              : systemLocaleName(values['LANG']!),
        ),
        loading: () => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(),
        ),
        error: (_, _) => Text(context.l10n.unavailable),
      );
}

class SystemLocaleEditor extends ConsumerWidget {
  const SystemLocaleEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(systemLocaleProvider)
      .when(
        data: (configuration) => ref
            .watch(installedSystemLocalesProvider)
            .when(
              data: (installed) => _LocaleForm(
                configuration: configuration,
                installed: installed,
              ),
              loading: () => const _LocaleLoading(),
              error: (_, _) => _LoadError(
                message: context.l10n.localeListUnavailable,
                retry: () => ref.invalidate(installedSystemLocalesProvider),
              ),
            ),
        loading: () => const _LocaleLoading(),
        error: (_, _) => _LoadError(
          message: context.l10n.localeServiceUnavailable,
          retry: () => ref.invalidate(systemLocaleProvider),
        ),
      );
}

class _LocaleLoading extends StatelessWidget {
  const _LocaleLoading();

  @override
  Widget build(BuildContext context) => const LinearProgressIndicator();
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(message),
      TextButton(onPressed: retry, child: Text(context.l10n.retry)),
    ],
  );
}

class _LocaleForm extends HookConsumerWidget {
  const _LocaleForm({required this.configuration, required this.installed});
  final Map<String, String> configuration;
  final List<String> installed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseline = useState(configuration);
    final draft = useState(Map<String, String>.of(configuration));
    final saving = useState(false);
    final saved = useState(false);
    final error = useState<Object?>(null);
    final dirty = !mapEquals(baseline.value, draft.value);
    useEffect(() {
      if (!dirty && !saving.value) {
        baseline.value = configuration;
        draft.value = Map.of(configuration);
      }
      return null;
    }, [configuration]);
    final conflict = !mapEquals(baseline.value, configuration);

    void reset() {
      baseline.value = configuration;
      draft.value = Map.of(configuration);
      error.value = null;
      saved.value = false;
    }

    Future<void> apply() async {
      final expandable = ExpandableContainer.maybeOf(context);
      saving.value = true;
      saved.value = false;
      error.value = null;
      final changes = <String, String?>{
        if (draft.value['LANG'] != baseline.value['LANG'])
          'LANG': draft.value['LANG'],
      };
      try {
        final next = await ref
            .read(systemLocaleProvider.notifier)
            .apply(expected: baseline.value, changes: changes);
        if (!context.mounted) return;
        baseline.value = next;
        draft.value = Map.of(next);
        saved.value = true;
        expandable?.collapse();
      } on Object catch (failure) {
        if (!context.mounted) return;
        error.value = failure;
      } finally {
        if (context.mounted) saving.value = false;
      }
    }

    void selectLocale(String? locale) {
      final next = Map<String, String>.of(draft.value);
      if (locale == null) {
        next.remove('LANG');
      } else {
        next['LANG'] = locale;
      }
      draft.value = next;
      saved.value = false;
      error.value = null;
    }

    Widget field() {
      final choices = preferredSystemLocales(installed);
      final current = draft.value['LANG'];
      final selected = current == null ? null : systemLocaleName(current);
      // Preserve an existing non-installed locale without offering it as a new
      // choice, and leave existing legacy encodings untouched until edited.
      final names = {...choices.keys, ?selected}.toList()..sort();
      return DropdownSettingEditor<String>(
        dropdownKey: ValueKey('LANG:$current'),
        value: selected,
        saving: saving.value,
        onConfirm: dirty && !conflict ? apply : null,
        decoration: InputDecoration(
          filled: true,
          labelText: context.l10n.localeDefault,
        ),
        hint: Text(context.l10n.localeSystemDefault),
        items: [
          DropdownMenuItem<String>(
            child: Text(context.l10n.localeSystemDefault),
          ),
          for (final name in names)
            DropdownMenuItem(
              value: name,
              enabled: choices.containsKey(name),
              child: Text(name),
            ),
        ],
        onChanged: saving.value
            ? null
            : (name) => selectLocale(name == null ? null : choices[name]),
      );
    }

    final failure = error.value;
    final authorizationFailure =
        failure is DBusMethodResponseException &&
        (failure.errorName.contains('AccessDenied') ||
            failure.errorName.contains('NotAuthorized') ||
            failure.errorName.contains('AuthCanceled') ||
            failure.errorName.contains('InteractiveAuthorizationRequired'));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(),
        if (conflict || failure is SystemLocaleConflict)
          Text(context.l10n.localeChangedElsewhere),
        if (failure != null && failure is! SystemLocaleConflict)
          Text(
            authorizationFailure
                ? context.l10n.localeAuthorizationFailed
                : context.l10n.localeSaveFailed,
          ),
        if (saved.value) Text(context.l10n.localeSavedRestartSession),
        if (conflict || failure is SystemLocaleConflict)
          TextButton(
            onPressed: saving.value ? null : reset,
            child: Text(context.l10n.localeResetEdits),
          ),
      ],
    );
  }
}

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/widget/expandable_container.dart';

/// The one-line text editor shared by scalar settings.
///
/// The field takes the keyboard as soon as it is shown, so a setting reached by
/// search can be edited without another click. `Enter` (the framework
/// [ActivateIntent]) or the check button validates the text and commits it;
/// unparsable input keeps the editor open and shows an inline error instead of
/// writing it.
class SettingValueField<T> extends HookWidget {
  const SettingValueField({
    required this.text,
    required this.parse,
    required this.onCommit,
    super.key,
  });

  /// The current value, already formatted for display.
  final String text;

  /// Parses the edited text, or returns `null` when it is not a [T].
  final T? Function(String text) parse;

  /// Persists a parsed value. Called for `Enter` and for the check button.
  final ValueChanged<T> onCommit;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: text);
    final focusNode = useFocusNode();
    final invalid = useState(false);

    // Follow the stored value when it changes from outside (for example after a
    // reset), but never clobber what the user is typing.
    useEffect(() {
      if (!focusNode.hasFocus && controller.text != text) {
        controller.text = text;
      }
      return null;
    }, [text]);

    // Opening the editor is meant to be "edit right away": focus the field and
    // select the current value so typing replaces it.
    useEffect(() {
      var selectedAll = false;
      void selectAllOnFocus() {
        if (selectedAll || !focusNode.hasFocus) return;
        selectedAll = true;
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      }

      focusNode.addListener(selectAllOnFocus);
      selectAllOnFocus();
      return () => focusNode.removeListener(selectAllOnFocus);
    }, [controller, focusNode]);

    void commit() {
      final value = parse(controller.text);
      if (value == null) {
        invalid.value = true;
        return;
      }
      invalid.value = false;
      onCommit(value);
    }

    return Actions(
      // `Enter` while the field itself has focus arrives through the text input
      // action below; registering the intent as well keeps activation uniform
      // when focus sits on the surrounding editor chrome.
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            commit();
            return null;
          },
        ),
      },
      child: Row(
        spacing: 16,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                filled: true,
                errorText: invalid.value ? context.l10n.invalidValue : null,
              ),
              onChanged: (_) {
                if (invalid.value) {
                  invalid.value = false;
                }
              },
              onSubmitted: (_) => commit(),
            ),
          ),
          IconButton(
            tooltip: context.l10n.apply,
            icon: const Icon(MdiIcons.check),
            onPressed: commit,
          ),
        ],
      ),
    );
  }
}

/// Wiring for the scalar setting editors: reads the stored value and commits
/// edits through the settings store.
class SettingPropertySingleValueEditor<T> extends HookConsumerWidget
    implements SettingPropertyValueEditor<T> {
  const SettingPropertySingleValueEditor({
    required this.path,
    required this.property,
    required this.format,
    required this.parse,
    super.key,
  });

  @override
  final String path;

  @override
  final SettingProperty<T> property;

  final String Function(T value) format;
  final T? Function(String text) parse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = property.tryCastValue(
      ref.watch(jsonValueByPathProvider(path)),
    );

    void commit(T newValue) {
      ref
          .read(settingsPropertiesProvider.notifier)
          .updateProperty(path, property.serializeValue(newValue));
      ExpandableContainer.maybeOf(context)?.collapse();
    }

    return SettingValueField<T>(
      text: value == null ? '' : format(value),
      parse: parse,
      onCommit: commit,
    );
  }
}

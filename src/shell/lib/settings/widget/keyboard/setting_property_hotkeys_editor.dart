import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/util/json_converter/logical_key_set.dart';
import 'package:shell/shared/widget/expandable_container.dart';
import 'package:shell/shared/widget/hotkey_viewer.dart';
import 'package:shell/shared/widget/list_editor.dart';

/// Editor for a list of hotkeys bound to one action.
///
/// Reuses the shared [ListEditor] chrome (add / delete / save, staged edits) and
/// swaps the plain text field for a key-capture field that records a chord on
/// release. The list is persisted as an array of `"super+w"` strings; the
/// converter also accepts the legacy single-string form.
class SettingPropertyHotkeysEditor extends HookConsumerWidget
    implements SettingPropertyValueEditor<List<LogicalKeySet>> {
  const SettingPropertyHotkeysEditor({
    required this.path,
    required this.property,
    required this.onChanged,
    super.key,
  });

  @override
  final String path;

  @override
  final SettingProperty<List<LogicalKeySet>> property;

  final void Function(List<LogicalKeySet> newValue) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const single = LogicalKeySetConverter();
    final stored =
        property.tryCastValue(ref.watch(jsonValueByPathProvider(path))) ??
        const <LogicalKeySet>[];

    return ListEditor(
      initialValue: [for (final hotkey in stored) single.toJson(hotkey)],
      itemLabel: context.l10n.hotkeys,
      errorMessage: context.l10n.notSet,
      itemFieldBuilder: (context, controller, rebuild) =>
          _HotkeyCaptureField(controller: controller, onChanged: rebuild),
      onSave: (next) {
        final value = [for (final binding in next) single.fromJson(binding)];
        ref
            .read(settingsPropertiesProvider.notifier)
            .updateProperty(path, property.serializeValue(value));
        onChanged(value);
        ExpandableContainer.of(context).collapse();
      },
    );
  }
}

/// Records the chord the user holds and writes its serialized form into
/// [controller].
///
/// The chord is committed when the last key of the chord is released, so a
/// multi-key chord like `super+w` is captured whole. Keys without a known name
/// are ignored (they could not be parsed back).
class _HotkeyCaptureField extends HookWidget {
  const _HotkeyCaptureField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final keysPressed = useState<Set<LogicalKeyboardKey>>({});
    final heldCount = useState(0);
    final focusNode = useFocusNode();
    const converter = LogicalKeySetConverter();

    // An empty row is either the editor's initial row or one just added with
    // the Add button. It must own the keyboard: otherwise the previously
    // focused row keeps it and the chord replaces that binding. Request focus
    // explicitly once the row is attached; `Focus.autofocus` did not reliably
    // hand a row added to an already built editor the keyboard.
    final shouldAutofocus = controller.text.isEmpty;
    useEffect(() {
      if (!shouldAutofocus) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          focusNode.requestFocus();
        }
      });
      return null;
    }, []);

    LogicalKeySet? current() {
      if (controller.text.isEmpty) {
        return null;
      }
      try {
        return converter.fromJson(controller.text);
      } on Object catch (_) {
        return null;
      }
    }

    void commit() {
      final serialized = converter.toJson(
        LogicalKeySet.fromSet(keysPressed.value),
      );
      if (serialized.isNotEmpty) {
        controller.text = serialized;
        onChanged();
      }
    }

    final pressedChord = keysPressed.value.isEmpty
        ? null
        : LogicalKeySet.fromSet(keysPressed.value);
    final stored = current();

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (heldCount.value == 0) {
            keysPressed.value = {};
          }
          keysPressed.value = {...keysPressed.value, event.logicalKey};
          heldCount.value++;
          return KeyEventResult.handled;
        }
        if (event is KeyUpEvent) {
          heldCount.value = (heldCount.value - 1).clamp(0, 1 << 30);
          if (heldCount.value == 0) {
            commit();
            keysPressed.value = {};
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.handled;
      },
      child: InkWell(
        onTap: focusNode.requestFocus,
        child: InputDecorator(
          decoration: InputDecoration(
            filled: true,
            labelText: context.l10n.hotkeys,
          ),
          child: SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: switch ((pressedChord, stored)) {
                (final LogicalKeySet chord, _) => HotkeyViewer(hotkey: chord),
                (null, final LogicalKeySet hotkey) => HotkeyViewer(
                  hotkey: hotkey,
                ),
                _ => Text(context.l10n.pressAnyKey),
              },
            ),
          ),
        ),
      ),
    );
  }
}

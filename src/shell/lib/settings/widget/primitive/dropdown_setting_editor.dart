import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';

/// Controlled dropdown with the same inline confirmation as text settings.
/// Callers stage changes through [onChanged] and persist through [onConfirm].
///
/// The dropdown takes the keyboard when the editor opens. Once a choice has
/// been staged, `Enter` confirms it — just like the text settings — while
/// `Space` still opens the menu to pick another value.
class DropdownSettingEditor<T> extends StatefulWidget {
  const DropdownSettingEditor({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.onConfirm,
    this.decoration = const InputDecoration(filled: true),
    this.hint,
    this.saving = false,
    this.dropdownKey,
    super.key,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final VoidCallback? onConfirm;
  final InputDecoration decoration;
  final Widget? hint;
  final bool saving;
  final Key? dropdownKey;

  @override
  State<DropdownSettingEditor<T>> createState() =>
      _DropdownSettingEditorState<T>();
}

class _DropdownSettingEditorState<T> extends State<DropdownSettingEditor<T>> {
  /// Whether a choice was staged since the editor opened. `Enter` only
  /// validates then; otherwise it keeps its usual meaning and opens the menu.
  bool _dirty = false;

  void _handleChanged(T? value) {
    _dirty = true;
    widget.onChanged?.call(value);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final onConfirm = widget.onConfirm;
    if (!_dirty || widget.saving || onConfirm == null) {
      // Nothing staged: let the dropdown handle `Enter` as usual (it opens the
      // menu through its own `ActivateIntent` action).
      return KeyEventResult.ignored;
    }
    onConfirm();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Row(
    spacing: 16,
    children: [
      Expanded(
        // The dropdown maps `ActivateIntent` to opening its menu, so a staged
        // choice needs the raw key event to be validated before that action
        // runs. `Space` is left alone and still opens the menu.
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _handleKeyEvent,
          child: DropdownButtonFormField<T>(
            key: widget.dropdownKey ?? ValueKey(widget.value),
            initialValue: widget.value,
            isExpanded: true,
            autofocus: true,
            decoration: widget.decoration,
            hint: widget.hint,
            items: widget.items,
            onChanged: widget.saving ? null : _handleChanged,
          ),
        ),
      ),
      IconButton(
        tooltip: context.l10n.apply,
        icon: widget.saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(MdiIcons.check),
        onPressed: widget.saving ? null : widget.onConfirm,
      ),
    ],
  );
}

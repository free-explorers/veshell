import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';

/// Controlled dropdown with the same inline confirmation as text settings.
/// Callers stage changes through [onChanged] and persist through [onConfirm].
class DropdownSettingEditor<T> extends StatelessWidget {
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
  Widget build(BuildContext context) => Row(
    spacing: 16,
    children: [
      Expanded(
        child: DropdownButtonFormField<T>(
          key: dropdownKey ?? ValueKey(value),
          initialValue: value,
          isExpanded: true,
          decoration: decoration,
          hint: hint,
          items: items,
          onChanged: saving ? null : onChanged,
        ),
      ),
      IconButton(
        tooltip: context.l10n.apply,
        icon: saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(MdiIcons.check),
        onPressed: saving ? null : onConfirm,
      ),
    ],
  );
}

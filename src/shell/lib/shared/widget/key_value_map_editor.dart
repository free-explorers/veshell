import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';

/// A reusable editor for a `Map<String, String>` laid out as key/value rows.
///
/// Edits are staged locally and committed once through [onSave], so a
/// half-typed key never reaches the caller. A fully blank row is skipped, and a
/// duplicate key — or one rejected by [isValidKey] — blocks the save with
/// [errorMessage] shown inline.
///
/// The fixed action labels come from the shell catalog; the caller supplies the
/// field labels and the validation message, so the same widget can back any
/// map-valued setting.
class KeyValueMapEditor extends StatefulWidget {
  const KeyValueMapEditor({
    required this.initialValue,
    required this.onSave,
    required this.keyLabel,
    required this.valueLabel,
    required this.errorMessage,
    this.isValidKey,
    super.key,
  });

  /// The map to edit. Read once when the editor is created; the widget owns the
  /// edits until they are saved.
  final Map<String, String> initialValue;

  /// Called with the staged map when the user saves.
  final ValueChanged<Map<String, String>> onSave;

  /// Label for the key field of each row.
  final String keyLabel;

  /// Label for the value field of each row.
  final String valueLabel;

  /// Shown when a key is empty, malformed, or duplicates another row.
  final String errorMessage;

  /// Whether a non-empty key is acceptable. Defaults to accepting any key; the
  /// editor always rejects empty and duplicate keys on its own.
  final bool Function(String key)? isValidKey;

  @override
  State<KeyValueMapEditor> createState() => _KeyValueMapEditorState();
}

class _KeyValueMapEditorState extends State<KeyValueMapEditor> {
  late final List<_KeyValueEntry> _entries;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _entries = [
      for (final entry in widget.initialValue.entries)
        _KeyValueEntry(key: entry.key, value: entry.value),
    ];
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _add() {
    setState(() {
      _entries.add(_KeyValueEntry());
      _invalid = false;
    });
  }

  void _remove(_KeyValueEntry entry) {
    setState(() {
      _entries.remove(entry);
      entry.dispose();
      _invalid = false;
    });
  }

  void _save() {
    final next = <String, String>{};
    for (final entry in _entries) {
      final key = entry.keyController.text.trim();
      final value = entry.valueController.text;
      // A fully blank row is a leftover of "Add"; ignore it.
      if (key.isEmpty && value.isEmpty) continue;
      final valid = key.isNotEmpty && (widget.isValidKey?.call(key) ?? true);
      if (!valid || next.containsKey(key)) {
        setState(() => _invalid = true);
        return;
      }
      next[key] = value;
    }
    widget.onSave(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in _entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: TextField(
                    controller: entry.keyController,
                    decoration: InputDecoration(
                      filled: true,
                      labelText: widget.keyLabel,
                    ),
                    onChanged: (_) {
                      if (_invalid) setState(() => _invalid = false);
                    },
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: entry.valueController,
                    decoration: InputDecoration(
                      filled: true,
                      labelText: widget.valueLabel,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(MdiIcons.delete),
                  tooltip: context.l10n.delete,
                  onPressed: () => _remove(entry),
                ),
              ],
            ),
          ),
        if (_invalid)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              widget.errorMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Row(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _add,
              icon: const Icon(MdiIcons.plus),
              label: Text(context.l10n.add),
            ),
            const Spacer(),
            FilledButton(onPressed: _save, child: Text(context.l10n.save)),
          ],
        ),
      ],
    );
  }
}

/// One staged row, owning its text controllers.
class _KeyValueEntry {
  _KeyValueEntry({String key = '', String value = ''})
    : keyController = TextEditingController(text: key),
      valueController = TextEditingController(text: value);

  final TextEditingController keyController;
  final TextEditingController valueController;

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

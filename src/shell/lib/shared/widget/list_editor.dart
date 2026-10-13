import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';

/// A reusable editor for a `List<String>` laid out as one field per row.
///
/// Sibling of the key/value map editor: edits are staged locally and committed
/// once through [onSave], so a half-typed item never reaches the caller. The
/// editor always shows at least one row ready to fill — even when
/// [initialValue] is empty — and a fully blank row is skipped on save. A
/// duplicate item — or one rejected by [isValidItem] — blocks the save with
/// [errorMessage] shown inline. The row order is preserved.
///
/// The fixed action labels come from the shell catalog; the caller supplies the
/// field label and the validation message, so the same widget can back any
/// list-valued setting.
class ListEditor extends StatefulWidget {
  const ListEditor({
    required this.initialValue,
    required this.onSave,
    required this.itemLabel,
    required this.errorMessage,
    this.isValidItem,
    this.itemFieldBuilder,
    super.key,
  });

  /// The list to edit. Read once when the editor is created; the widget owns
  /// the edits until they are saved.
  final List<String> initialValue;

  /// Called with the staged list when the user saves.
  final ValueChanged<List<String>> onSave;

  /// Label for the field of each row.
  final String itemLabel;

  /// Shown when an item is malformed or duplicates another row.
  final String errorMessage;

  /// Whether a non-empty item is acceptable. Defaults to accepting any item;
  /// the editor always rejects blank and duplicate items on its own.
  final bool Function(String item)? isValidItem;

  /// Optional builder for a row's field, letting callers swap the plain text
  /// field for a picker. It receives the row's controller — the canonical value
  /// the editor saves — and a `rebuild` callback. Defaults to a text field.
  final Widget Function(
    BuildContext context,
    TextEditingController controller,
    VoidCallback rebuild,
  )?
  itemFieldBuilder;

  @override
  State<ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends State<ListEditor> {
  late final List<_ListEntry> _entries;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _entries = [
      for (final item in widget.initialValue) _ListEntry(value: item),
    ];
    // Nothing to edit yet: leave a row ready to fill so the user can start
    // typing without pressing "Add" first.
    if (_entries.isEmpty) {
      _entries.add(_ListEntry());
    }
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
      _entries.add(_ListEntry());
      _invalid = false;
    });
  }

  void _remove(_ListEntry entry) {
    setState(() {
      _entries.remove(entry);
      entry.dispose();
      // Never leave an empty editor: keep a row ready to fill.
      if (_entries.isEmpty) {
        _entries.add(_ListEntry());
      }
      _invalid = false;
    });
  }

  void _save() {
    final next = <String>[];
    for (final entry in _entries) {
      final item = entry.controller.text.trim();
      // A blank row is a leftover of "Add"; ignore it.
      if (item.isEmpty) continue;
      final valid = widget.isValidItem?.call(item) ?? true;
      if (!valid || next.contains(item)) {
        setState(() => _invalid = true);
        return;
      }
      next.add(item);
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
                  child:
                      widget.itemFieldBuilder?.call(
                        context,
                        entry.controller,
                        () => setState(() {}),
                      ) ??
                      TextField(
                        controller: entry.controller,
                        decoration: InputDecoration(
                          filled: true,
                          labelText: widget.itemLabel,
                        ),
                        onChanged: (_) {
                          if (_invalid) setState(() => _invalid = false);
                        },
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
        const SizedBox(height: 8),
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

/// One staged row, owning its text controller.
class _ListEntry {
  _ListEntry({String value = ''})
    : controller = TextEditingController(text: value);

  final TextEditingController controller;

  void dispose() {
    controller.dispose();
  }
}

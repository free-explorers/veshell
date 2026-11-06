import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/installed_cursor_themes.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/cursor_theme_preview.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/widget/primitive/dropdown_setting_editor.dart';
import 'package:shell/shared/widget/expandable_container.dart';

/// Stored value of `theme.cursorTheme` that keeps the session's cursor.
const systemCursorTheme = '';

/// Sizes offered by the cursor size picker: the nominal sizes Xcursor themes
/// commonly ship, so the chosen size has a sharp image.
const cursorSizeChoices = [24, 32, 48, 64, 96];

/// Cursor-theme picker: the session default plus the installed Xcursor themes.
///
/// A stale configured value stays listed so it can be corrected instead of
/// silently disappearing from the dropdown.
class CursorThemeEditor extends HookConsumerWidget
    implements SettingPropertyValueEditor<String> {
  const CursorThemeEditor({
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
    final stored =
        property
            .tryCastValue(ref.watch(jsonValueByPathProvider(path)))
            ?.trim() ??
        systemCursorTheme;
    final draft = useState(stored);
    useEffect(() {
      draft.value = stored;
      return null;
    }, [stored]);

    final themes = [...ref.watch(installedCursorThemeNamesProvider)];
    if (stored != systemCursorTheme && !themes.contains(stored)) {
      themes
        ..add(stored)
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }

    return DropdownSettingEditor<String>(
      dropdownKey: ValueKey('${draft.value}|${themes.join(',')}'),
      value: draft.value,
      decoration: InputDecoration(filled: true, labelText: property.name),
      items: [
        DropdownMenuItem(
          value: systemCursorTheme,
          child: _CursorThemeLabel(
            label: context.l10n.cursorThemeSystemDefault,
          ),
        ),
        for (final theme in themes)
          DropdownMenuItem(
            value: theme,
            child: _CursorThemeLabel(theme: theme, label: theme),
          ),
      ],
      onChanged: (theme) {
        if (theme == null) return;
        draft.value = theme;
      },
      onConfirm: () {
        ref
            .read(settingsPropertiesProvider.notifier)
            .updateProperty(path, property.serializeValue(draft.value));
        ExpandableContainer.maybeOf(context)?.collapse();
      },
    );
  }
}

/// Trailing summary of the `theme.cursorTheme` property.
class CursorThemeValue extends ConsumerWidget {
  const CursorThemeValue({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(jsonValueByPathProvider(path));
    if (value is! String || value.trim().isEmpty) {
      return Text(context.l10n.cursorThemeSystemDefault);
    }
    return _CursorThemeLabel(theme: value, label: value, compact: true);
  }
}

/// Cursor-size picker over [cursorSizeChoices], keeping a hand-edited size
/// listed.
class CursorSizeEditor extends HookConsumerWidget
    implements SettingPropertyValueEditor<int> {
  const CursorSizeEditor({
    required this.path,
    required this.property,
    super.key,
  });

  @override
  final String path;

  @override
  final SettingProperty<int> property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = property.tryCastValue(
      ref.watch(jsonValueByPathProvider(path)),
    );
    final draft = useState<int?>(stored);
    useEffect(() {
      draft.value = stored;
      return null;
    }, [stored]);

    final sizes = [...cursorSizeChoices];
    if (stored != null && stored > 0 && !sizes.contains(stored)) {
      sizes
        ..add(stored)
        ..sort();
    }

    return DropdownSettingEditor<int>(
      dropdownKey: ValueKey('${draft.value}|${sizes.join(',')}'),
      value: draft.value,
      decoration: InputDecoration(filled: true, labelText: property.name),
      hint: Text(context.l10n.notSet),
      items: [
        for (final size in sizes)
          DropdownMenuItem(
            value: size,
            child: Text(context.l10n.cursorSizePixels(size)),
          ),
      ],
      onChanged: (size) {
        if (size == null) return;
        draft.value = size;
      },
      onConfirm: () {
        final size = draft.value;
        if (size == null) return;
        ref
            .read(settingsPropertiesProvider.notifier)
            .updateProperty(path, property.serializeValue(size));
        ExpandableContainer.maybeOf(context)?.collapse();
      },
    );
  }
}

/// Trailing summary of the `theme.cursorSize` property.
class CursorSizeValue extends ConsumerWidget {
  const CursorSizeValue({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(jsonValueByPathProvider(path));
    if (value is! int || value <= 0) return Text(context.l10n.notSet);
    return Text(context.l10n.cursorSizePixels(value));
  }
}

/// A theme name led by that theme's arrow, or by an empty slot for the
/// session default.
class _CursorThemeLabel extends StatelessWidget {
  const _CursorThemeLabel({
    required this.label,
    this.theme,
    this.compact = false,
  });

  final String label;
  final String? theme;

  /// Size to the content instead of filling the dropdown row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = this.theme;
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      spacing: 8,
      children: [
        SizedBox.square(
          dimension: 20,
          child: theme == null ? null : CursorThemePreview(theme: theme),
        ),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// The arrow of [theme], or an empty slot while it resolves or when the theme
/// has none.
class CursorThemePreview extends HookConsumerWidget {
  const CursorThemePreview({required this.theme, super.key});

  final String theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cursor = ref.watch(cursorThemePreviewProvider(theme)).value;
    final image = useFuture(
      useMemoized(
        () => cursor == null ? Future<ui.Image?>.value() : _decode(cursor),
        [cursor],
      ),
    ).data;
    useEffect(() => image?.dispose, [image]);
    if (image == null) return const SizedBox.shrink();
    return RawImage(image: image, fit: BoxFit.contain);
  }

  static Future<ui.Image?> _decode(CursorImage cursor) {
    final completer = Completer<ui.Image?>();
    ui.decodeImageFromPixels(
      cursor.pixels,
      cursor.width,
      cursor.height,
      ui.PixelFormat.bgra8888,
      completer.complete,
    );
    return completer.future;
  }
}

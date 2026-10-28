import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/shell_icon.dart';

/// Finds the icon showing [icon], drawn by a [ShellIcon] or a plain [Icon].
///
/// `find.byIcon` only matches [Icon]. A [ShellIcon] draws its glyph
/// grid-fitted once the icon font is read, and an [Icon] before that, so
/// matching the [ShellIcon] itself keeps a test independent of that timing.
/// The fallback [Icon] inside a [ShellIcon] is not counted a second time.
Finder findIcon(IconData icon) => find.byElementPredicate((element) {
  final widget = element.widget;
  if (widget is ShellIcon) return widget.icon == icon;
  return widget is Icon &&
      widget.icon == icon &&
      element.findAncestorWidgetOfExactType<ShellIcon>() == null;
}, description: 'icon $icon');

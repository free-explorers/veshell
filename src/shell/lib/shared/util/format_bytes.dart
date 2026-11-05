import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';

/// A byte count in binary units (`B`, `KiB`, `MiB`, ...), localized: one
/// decimal below 10 of a unit, none above.
String formatBytes(BuildContext context, int bytes) {
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final digits = value >= 10 || unitIndex == 0 ? 0 : 1;
  return context.measurement(value, units[unitIndex], decimalDigits: digits);
}

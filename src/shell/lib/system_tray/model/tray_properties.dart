import 'dart:typed_data';

import 'package:dbus/dbus.dart';
import 'package:shell/system_tray/model/tray_item.dart';

/// The interface every tray item implements.
const trayItemInterface = 'org.kde.StatusNotifierItem';

/// Builds [base] anew from the result of `GetAll` on [trayItemInterface].
///
/// Properties an application leaves out or types wrongly keep their default:
/// implementations differ in how complete they are, and one bad property must
/// not hide the whole item.
TrayItem trayItemWithProperties(
  TrayItem base,
  Map<String, DBusValue> properties,
) {
  final menu = properties['Menu'];
  final menuPath = menu is DBusObjectPath ? menu.value : null;
  return base.copyWith(
    category: _string(properties['Category']),
    itemId: _string(properties['Id']),
    title: _string(properties['Title']),
    status: TrayItemStatus.fromDbusValue(_string(properties['Status'])),
    iconName: _string(properties['IconName']),
    iconPixmaps: trayPixmapsFrom(properties['IconPixmap']),
    attentionIconName: _string(properties['AttentionIconName']),
    attentionIconPixmaps: trayPixmapsFrom(properties['AttentionIconPixmap']),
    iconThemePath: _string(properties['IconThemePath']),
    toolTip: trayToolTipFrom(properties['ToolTip']),
    itemIsMenu: _bool(properties['ItemIsMenu']),
    // `/` is what applications without a menu (and Electron before it has
    // built one) report.
    menuPath: menuPath == null || menuPath == '/' ? null : menuPath,
  );
}

/// Decodes an `a(iiay)` pixmap list, dropping malformed entries.
///
/// The specification's pixels are ARGB32 in network byte order (`A R G B`
/// bytes); they are reordered to the `R G B A` bytes Flutter decodes.
List<TrayPixmap> trayPixmapsFrom(DBusValue? value) {
  if (value is! DBusArray) return const [];
  final pixmaps = <TrayPixmap>[];
  for (final entry in value.children) {
    if (entry is! DBusStruct || entry.children.length != 3) continue;
    final [width, height, data] = entry.children;
    if (width is! DBusInt32 || height is! DBusInt32 || data is! DBusArray) {
      continue;
    }
    final size = width.value * height.value * 4;
    if (width.value <= 0 || height.value <= 0 || data.children.length != size) {
      continue;
    }
    final argb = Uint8List.fromList(data.mapByte().toList());
    final rgba = Uint8List(size);
    for (var i = 0; i < size; i += 4) {
      rgba[i] = argb[i + 1];
      rgba[i + 1] = argb[i + 2];
      rgba[i + 2] = argb[i + 3];
      rgba[i + 3] = argb[i];
    }
    pixmaps.add(
      TrayPixmap(width: width.value, height: height.value, rgba: rgba),
    );
  }
  return pixmaps;
}

/// The pixmap to draw at [physicalSize] pixels: the smallest that is at least
/// that large, so it is only ever scaled down, or the largest there is.
TrayPixmap? bestTrayPixmap(List<TrayPixmap> pixmaps, int physicalSize) {
  if (pixmaps.isEmpty) return null;
  final sorted = [...pixmaps]..sort((a, b) => a.width.compareTo(b.width));
  return sorted.firstWhere(
    (pixmap) => pixmap.width >= physicalSize && pixmap.height >= physicalSize,
    orElse: () => sorted.last,
  );
}

/// Decodes the `(sa(iiay)ss)` tooltip, or `null` when there is none.
TrayToolTip? trayToolTipFrom(DBusValue? value) {
  if (value is! DBusStruct || value.children.length != 4) return null;
  final [iconName, pixmaps, title, description] = value.children;
  final toolTip = TrayToolTip(
    iconName: _string(iconName),
    iconPixmaps: trayPixmapsFrom(pixmaps),
    title: _string(title),
    description: _string(description),
  );
  return toolTip.title.isEmpty && toolTip.description.isEmpty ? null : toolTip;
}

final _markupTag = RegExp('<[^>]*>');
final _lineBreakTag = RegExp(r'<br\s*/?>', caseSensitive: false);

/// [markup] as plain text: the tooltip description may carry a subset of
/// HTML. Line breaks are kept, other tags dropped and entities decoded.
String plainToolTipText(String markup) => markup
    .replaceAll(_lineBreakTag, '\n')
    .replaceAll(_markupTag, '')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .trim();

/// A string, or an object path (a `DBusString` too) some items send instead.
String _string(DBusValue? value) => value is DBusString ? value.value : '';

bool _bool(DBusValue? value) => value is DBusBoolean && value.value;

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

/// The interface of a tray item's menu.
const trayMenuInterface = 'com.canonical.dbusmenu';

/// The properties `GetLayout` is asked for; an empty list would mean "all of
/// them", which includes icon data the shell would decode for nothing.
const trayMenuProperties = [
  'type',
  'label',
  'enabled',
  'visible',
  'icon-name',
  'icon-data',
  'toggle-type',
  'toggle-state',
  'children-display',
];

/// How a menu entry toggles, from its `toggle-type`.
enum TrayMenuToggle { none, checkmark, radio }

/// One entry of a `com.canonical.dbusmenu` layout.
@immutable
class TrayMenuEntry {
  const TrayMenuEntry({
    required this.id,
    this.label = '',
    this.enabled = true,
    this.visible = true,
    this.isSeparator = false,
    this.iconName = '',
    this.iconData,
    this.toggle = TrayMenuToggle.none,
    this.toggled,
    this.isSubmenu = false,
    this.children = const [],
  });

  final int id;

  /// The label with its mnemonic markers removed.
  final String label;
  final bool enabled;
  final bool visible;
  final bool isSeparator;
  final String iconName;

  /// A PNG image, when the application sends the icon itself.
  final Uint8List? iconData;
  final TrayMenuToggle toggle;

  /// `toggle-state`: `true` when on, `false` when off, `null` when unknown.
  final bool? toggled;

  /// Whether the entry opens a submenu: it has children, or announces some
  /// it will populate on `AboutToShow`.
  final bool isSubmenu;
  final List<TrayMenuEntry> children;

  /// The children that are shown.
  Iterable<TrayMenuEntry> get visibleChildren =>
      children.where((child) => child.visible);
}

/// Decodes a `(ia{sv}av)` layout node and its descendants, or `null` when it
/// is malformed.
TrayMenuEntry? trayMenuEntryFrom(DBusValue value) {
  if (value is DBusVariant) return trayMenuEntryFrom(value.value);
  if (value is! DBusStruct || value.children.length != 3) return null;
  final [id, properties, children] = value.children;
  if (id is! DBusInt32 || properties is! DBusDict || children is! DBusArray) {
    return null;
  }
  final props = <String, DBusValue>{};
  properties.children.forEach((key, value) {
    if (key is DBusString) {
      props[key.value] = value is DBusVariant ? value.value : value;
    }
  });
  final entries = children.children
      .map(trayMenuEntryFrom)
      .whereType<TrayMenuEntry>()
      .toList(growable: false);
  final iconData = props['icon-data'];
  final toggleState = props['toggle-state'];
  return TrayMenuEntry(
    id: id.value,
    label: trayMenuLabel(_string(props['label'])),
    enabled: _bool(props['enabled'], fallback: true),
    visible: _bool(props['visible'], fallback: true),
    isSeparator: _string(props['type']) == 'separator',
    iconName: _string(props['icon-name']),
    iconData: iconData is DBusArray && iconData.children.isNotEmpty
        ? Uint8List.fromList(iconData.mapByte().toList())
        : null,
    toggle: switch (_string(props['toggle-type'])) {
      'checkmark' => TrayMenuToggle.checkmark,
      'radio' => TrayMenuToggle.radio,
      _ => TrayMenuToggle.none,
    },
    toggled: switch (toggleState) {
      DBusInt32(value: 1) => true,
      DBusInt32(value: 0) => false,
      _ => null,
    },
    isSubmenu:
        entries.isNotEmpty || _string(props['children-display']) == 'submenu',
    children: entries,
  );
}

/// [label] without its mnemonic markers: a single `_` marks the access key
/// and `__` is a literal underscore.
String trayMenuLabel(String label) {
  final buffer = StringBuffer();
  for (var i = 0; i < label.length; i++) {
    final char = label[i];
    if (char == '_') {
      if (i + 1 < label.length && label[i + 1] == '_') {
        buffer.write('_');
        i++;
      }
      continue;
    }
    buffer.write(char);
  }
  return buffer.toString();
}

String _string(DBusValue? value) => value is DBusString ? value.value : '';

bool _bool(DBusValue? value, {required bool fallback}) =>
    value is DBusBoolean ? value.value : fallback;

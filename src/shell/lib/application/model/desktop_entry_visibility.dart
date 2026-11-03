import 'dart:io';

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';

/// Visibility of a desktop entry on the current session.
///
/// The freedesktop Desktop Entry spec lets an entry restrict itself to (or
/// exclude itself from) specific desktops through `OnlyShowIn`/`NotShowIn`.
/// Honouring them keeps desktop-specific duplicates out of the app drawer: on a
/// Veshell session the `OnlyShowIn=KDE` `gnome-system-monitor-kde` entry is
/// hidden, so the canonical `org.gnome.SystemMonitor` one is launched.

/// Whether [entry] should be offered on the current desktop session.
///
/// A non-empty `OnlyShowIn` hides the entry unless the current desktop is
/// listed; a `NotShowIn` that lists the current desktop always hides it.
/// Comparison is case-insensitive.
bool shownInCurrentDesktop(
  LocalizedDesktopEntry entry, {
  Set<String>? currentDesktop,
}) {
  final current = currentDesktop ?? currentDesktopNames();
  final onlyShowIn = _desktopList(
    entry.entries[DesktopEntryKey.onlyShowIn.string],
  );
  if (onlyShowIn.isNotEmpty && !onlyShowIn.any(current.contains)) {
    return false;
  }
  final notShowIn = _desktopList(
    entry.entries[DesktopEntryKey.notShowIn.string],
  );
  if (notShowIn.any(current.contains)) {
    return false;
  }
  return true;
}

/// The desktop names of the running session, lowercased.
///
/// `XDG_CURRENT_DESKTOP` is the spec's source and is a colon-separated list.
/// `XDG_SESSION_DESKTOP` and `DESKTOP_SESSION` are only used as fallbacks when
/// the former is unset or empty: sessions that set it may still carry a
/// legacy value in one of the others (Veshell exports
/// `DESKTOP_SESSION=gnome` for Electron's keyring detection, for example).
Set<String> currentDesktopNames([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final names = <String>{};

  void addNames(String? value) {
    if (value == null) {
      return;
    }
    for (final part in value.split(':')) {
      final name = part.trim().toLowerCase();
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
  }

  final current = env['XDG_CURRENT_DESKTOP'];
  if (current != null && current.trim().isNotEmpty) {
    addNames(current);
    return names;
  }

  addNames(env['XDG_SESSION_DESKTOP']);
  addNames(env['DESKTOP_SESSION']);
  return names;
}

List<String> _desktopList(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [];
  }
  return raw
      .getStringList()
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toList();
}

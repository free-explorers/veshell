import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';

/// Application-identity helpers shared by the matcher and the launcher.
///
/// Desktops sometimes ship several `.desktop` entries for one program: a
/// generic id and a desktop-specific one, like `org.gnome.SystemMonitor` and
/// `gnome-system-monitor-kde` (the latter is `OnlyShowIn=KDE`). The matcher
/// must recognise such entries as the same application without merging
/// genuinely different ones.
///
/// The only alias signal used here is `StartupWMClass`: it is the field
/// desktops themselves use to bind windows to an entry, so a collision is rare
/// and intentional (on a typical install exactly one pair collides, and it is
/// the system-monitor pair above). The executable is deliberately *not* used:
/// `Exec`/`TryExec` are shared by unrelated entries (`gnome-control-center`
/// has 28, `flatpak` 11, `libreoffice` 8), so matching on the basename merges
/// them.

/// Resolves the desktop entry for [appId] with the shell's usual rules: an
/// exact entry id, then the binary name ([binaryToAppId]), then a
/// case-insensitive `StartupWMClass` scan. Returns null when nothing matches.
LocalizedDesktopEntry? resolveLocalizedDesktopEntry({
  required String appId,
  required Map<String, LocalizedDesktopEntry> entries,
  required Map<String, String?> binaryToAppId,
}) {
  if (appId.isEmpty) {
    return null;
  }
  final direct = entries[appId] ?? entries[binaryToAppId[appId]];
  if (direct != null) {
    return direct;
  }
  final normalized = appId.toLowerCase();
  for (final entry in entries.values) {
    final wmClass = _startupWmClass(entry);
    if (wmClass != null && wmClass == normalized) {
      return entry;
    }
  }
  return null;
}

/// Whether two resolved entries describe the same application: the same entry
/// id, or the same non-empty `StartupWMClass` (case-insensitive).
bool sameApplicationEntry(LocalizedDesktopEntry a, LocalizedDesktopEntry b) {
  if (a.desktopEntry.id == b.desktopEntry.id) {
    return true;
  }
  final aWmClass = _startupWmClass(a);
  return aWmClass != null && aWmClass == _startupWmClass(b);
}

/// Whether two app ids name the same application.
///
/// Only true when both resolve and their entries are the same application (see
/// [sameApplicationEntry]); unresolved ids are never assumed equal.
bool sameApplicationId({
  required String a,
  required String b,
  required Map<String, LocalizedDesktopEntry> entries,
  required Map<String, String?> binaryToAppId,
}) {
  if (a == b) {
    return true;
  }
  final entryA = resolveLocalizedDesktopEntry(
    appId: a,
    entries: entries,
    binaryToAppId: binaryToAppId,
  );
  final entryB = resolveLocalizedDesktopEntry(
    appId: b,
    entries: entries,
    binaryToAppId: binaryToAppId,
  );
  if (entryA == null || entryB == null) {
    return false;
  }
  return sameApplicationEntry(entryA, entryB);
}

/// Whether [reportedAppId] (a native window) and [launchAppId] (a tile) name
/// *different* applications.
///
/// Permissive by design: an empty reported id, an unresolved id or entry on
/// either side, or two entries that are the same application are all not a
/// conflict. Only a genuine disagreement between two resolvable, different
/// applications is.
bool applicationsDiffer({
  required String reportedAppId,
  required String launchAppId,
  required Map<String, LocalizedDesktopEntry> entries,
  required Map<String, String?> binaryToAppId,
}) {
  if (reportedAppId.isEmpty) {
    return false;
  }
  final reportedEntry = resolveLocalizedDesktopEntry(
    appId: reportedAppId,
    entries: entries,
    binaryToAppId: binaryToAppId,
  );
  if (reportedEntry == null) {
    return false;
  }
  final launchEntry = resolveLocalizedDesktopEntry(
    appId: launchAppId,
    entries: entries,
    binaryToAppId: binaryToAppId,
  );
  if (launchEntry == null) {
    return false;
  }
  return !sameApplicationEntry(reportedEntry, launchEntry);
}

String? _startupWmClass(LocalizedDesktopEntry entry) {
  final value = entry.entries[DesktopEntryKey.startupWmClass.string]?.trim();
  return (value == null || value.isEmpty) ? null : value.toLowerCase();
}

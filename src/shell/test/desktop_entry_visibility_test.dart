import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:shell/application/model/desktop_entry_visibility.dart';

LocalizedDesktopEntry _entry({
  required String id,
  String? onlyShowIn,
  String? notShowIn,
}) {
  final entries = <String, String>{};
  if (onlyShowIn != null) {
    entries[DesktopEntryKey.onlyShowIn.string] = onlyShowIn;
  }
  if (notShowIn != null) {
    entries[DesktopEntryKey.notShowIn.string] = notShowIn;
  }
  return LocalizedDesktopEntry(
    desktopEntry: DesktopEntry(entries: const {}, id: id),
    entries: entries,
  );
}

void main() {
  test('hides an OnlyShowIn=KDE entry on a veshell session', () {
    final kde = _entry(id: 'gnome-system-monitor-kde', onlyShowIn: 'KDE;');
    expect(shownInCurrentDesktop(kde, currentDesktop: {'veshell'}), isFalse);
  });

  test('shows an entry with no OnlyShowIn/NotShowIn', () {
    final entry = _entry(id: 'org.gnome.SystemMonitor');
    expect(shownInCurrentDesktop(entry, currentDesktop: {'veshell'}), isTrue);
  });

  test('honours OnlyShowIn case-insensitively', () {
    final entry = _entry(id: 'x', onlyShowIn: 'GNOME;KDE;');
    expect(shownInCurrentDesktop(entry, currentDesktop: {'veshell'}), isFalse);
    expect(shownInCurrentDesktop(entry, currentDesktop: {'gnome'}), isTrue);
  });

  test('NotShowIn hides the listed desktop', () {
    final entry = _entry(id: 'x', notShowIn: 'GNOME;');
    expect(shownInCurrentDesktop(entry, currentDesktop: {'gnome'}), isFalse);
    expect(shownInCurrentDesktop(entry, currentDesktop: {'kde'}), isTrue);
  });

  test('currentDesktopNames splits and lowercases XDG_CURRENT_DESKTOP', () {
    expect(currentDesktopNames({'XDG_CURRENT_DESKTOP': 'GNOME:Unity'}), {
      'gnome',
      'unity',
    });
  });

  test('currentDesktopNames reads the session fallbacks', () {
    expect(currentDesktopNames({'DESKTOP_SESSION': 'plasma'}), {'plasma'});
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:shell/application/provider/app_drawer.dart';

LocalizedDesktopEntry _entry(String? name, {String? keywords}) =>
    LocalizedDesktopEntry(
      desktopEntry: DesktopEntry(entries: const {}, id: name),
      entries: {
        DesktopEntryKey.name.string: ?name,
        DesktopEntryKey.keywords.string: ?keywords,
      },
    );

List<String?> _names(List<LocalizedDesktopEntry> entries) =>
    entries.map((e) => e.entries[DesktopEntryKey.name.string]).toList();

void main() {
  final entries = [
    _entry('Firefox', keywords: 'Internet;WWW;Browser;Web;'),
    _entry('LibreOffice Writer', keywords: 'Text;Letter;'),
    _entry('Files'),
    _entry('GNOME Web'),
  ];

  test('an empty query lists every entry by name', () {
    expect(_names(filterDesktopEntries(entries, '')), [
      'Files',
      'Firefox',
      'GNOME Web',
      'LibreOffice Writer',
    ]);
  });

  test('the query is case-insensitive', () {
    expect(_names(filterDesktopEntries(entries, 'FiRe')), ['Firefox']);
  });

  test('keywords are case-insensitive', () {
    expect(_names(filterDesktopEntries(entries, 'browser')), ['Firefox']);
    expect(_names(filterDesktopEntries(entries, 'LETTER')), [
      'LibreOffice Writer',
    ]);
  });

  test('name prefixes rank before word and keyword matches', () {
    // `Files`/`Firefox` start with it; nothing else does.
    expect(_names(filterDesktopEntries(entries, 'fi')), ['Files', 'Firefox']);
    // `GNOME Web` by a name word, `Firefox` only by its keyword.
    expect(_names(filterDesktopEntries(entries, 'web')), [
      'GNOME Web',
      'Firefox',
    ]);
  });

  test('surrounding and repeated whitespace is ignored', () {
    expect(_names(filterDesktopEntries(entries, '  firefox ')), ['Firefox']);
    expect(_names(filterDesktopEntries(entries, 'libreoffice   wr')), [
      'LibreOffice Writer',
    ]);
  });

  test('every query word must start a word, in any order', () {
    expect(_names(filterDesktopEntries(entries, 'writ libre')), [
      'LibreOffice Writer',
    ]);
    expect(filterDesktopEntries(entries, 'writ firefox'), isEmpty);
  });

  test('an entry without a name does not break the filter', () {
    final broken = [...entries, _entry(null)];
    expect(_names(filterDesktopEntries(broken, 'fire')), ['Firefox']);
  });

  test('the most used applications lead a search, not the full list', () {
    final rankedIds = ['Firefox'];
    expect(_names(filterDesktopEntries(entries, 'fi', rankedIds: rankedIds)), [
      'Firefox',
      'Files',
    ]);
    // The empty search is the alphabetical index.
    expect(
      _names(filterDesktopEntries(entries, '', rankedIds: rankedIds)).first,
      'Files',
    );
  });

  group('matchedNameRanges', () {
    List<String> bold(String name, String query) => [
      for (final range in matchedNameRanges(name, query))
        range.textInside(name),
    ];

    test('marks each name word a query word starts', () {
      expect(bold('LibreOffice Writer', 'writ libre'), ['Libre', 'Writ']);
      expect(bold('Firefox', 'FIRE'), ['Fire']);
    });

    test('keeps the longest query word per name word', () {
      expect(bold('Firefox', 'f fire'), ['Fire']);
    });

    test('marks nothing for an empty or keyword-only match', () {
      expect(bold('Firefox', ''), isEmpty);
      expect(bold('Firefox', 'browser'), isEmpty);
    });
  });
}

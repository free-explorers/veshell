import 'dart:ui' show TextRange;

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/app_drawer_desktop_entries.dart';
import 'package:shell/application/provider/app_launch_history.dart';

part 'app_drawer.g.dart';

/// The launchable applications matching [filter], best matches first.
///
/// Derived synchronously from the loaded entry list, so a new filter has its
/// result in the same frame (no empty list while it "loads"), and auto-disposed
/// so the per-keystroke filters do not pile up for the whole session.
@riverpod
AsyncValue<List<LocalizedDesktopEntry>> appDrawerFilteredDesktopEntries(
  Ref ref,
  String filter,
) {
  final frequentIds = ref.watch(frequentAppIdsProvider);
  return ref
      .watch(appDrawerDesktopEntriesProvider)
      .whenData(
        (entries) =>
            filterDesktopEntries(entries, filter, rankedIds: frequentIds),
      );
}

/// The installed applications launched most, most used first.
@riverpod
AsyncValue<List<LocalizedDesktopEntry>> appDrawerFrequentDesktopEntries(
  Ref ref,
) {
  final frequentIds = ref.watch(frequentAppIdsProvider);
  return ref.watch(appDrawerDesktopEntriesProvider).whenData((entries) {
    final byId = {
      for (final entry in entries)
        if (entry.desktopEntry.id != null) entry.desktopEntry.id!: entry,
    };
    return [for (final id in frequentIds) ?byId[id]];
  });
}

/// Orders the [entries] matching [query], case-insensitively.
///
/// The query is split into words; surrounding and repeated whitespace is
/// ignored. Matches are ranked in three tiers, each sorted by name:
///
/// 1. the name starts with the query (`fire` → Firefox),
/// 2. every query word starts a word of the name (`writ libre` → LibreOffice
///    Writer),
/// 3. every query word starts a word of the name or of a keyword (`browser` →
///    Firefox, through its `Keywords`).
///
/// While searching, the applications in [rankedIds] (desktop file IDs, most
/// used first) lead their tier, so `fi` offers Firefox before Files once
/// Firefox is used more. An empty query matches every entry, by name only:
/// that list is the alphabetical index, which usage must not shuffle.
List<LocalizedDesktopEntry> filterDesktopEntries(
  Iterable<LocalizedDesktopEntry> entries,
  String query, {
  List<String> rankedIds = const [],
}) {
  final queryWords = _words(query);
  final normalizedQuery = queryWords.join(' ');

  final usageRank = queryWords.isEmpty
      ? const <String, int>{}
      : {for (final (rank, id) in rankedIds.indexed) id: rank};
  int rank(LocalizedDesktopEntry entry) =>
      usageRank[entry.desktopEntry.id] ?? usageRank.length;

  final candidates =
      [
        for (final entry in entries)
          (entry: entry, name: _name(entry), rank: rank(entry)),
      ]..sort((a, b) {
        final byRank = a.rank.compareTo(b.rank);
        return byRank != 0 ? byRank : a.name.compareTo(b.name);
      });

  bool startsWords(Iterable<String> words) => queryWords.every(
    (queryWord) => words.any((word) => word.startsWith(queryWord)),
  );

  final nameMatched = <LocalizedDesktopEntry>[];
  final namePartsMatched = <LocalizedDesktopEntry>[];
  final keywordsMatched = <LocalizedDesktopEntry>[];
  for (final (:entry, :name, rank: _) in candidates) {
    final nameWords = _words(name);
    if (name.startsWith(normalizedQuery)) {
      nameMatched.add(entry);
    } else if (startsWords(nameWords)) {
      namePartsMatched.add(entry);
    } else if (startsWords([...nameWords, ..._keywordWords(entry)])) {
      keywordsMatched.add(entry);
    }
  }
  return [...nameMatched, ...namePartsMatched, ...keywordsMatched];
}

/// The parts of [name] matched by [query]: for each word of the name, the
/// longest query word it starts with (case-insensitively), so the launcher can
/// show why an entry is listed. A match through the keywords marks nothing.
List<TextRange> matchedNameRanges(String name, String query) {
  final queryWords = _words(query);
  if (queryWords.isEmpty) {
    return const [];
  }
  final ranges = <TextRange>[];
  for (final word in RegExp(r'\S+').allMatches(name)) {
    final lowerWord = word[0]!.toLowerCase();
    var length = 0;
    for (final queryWord in queryWords) {
      if (queryWord.length > length && lowerWord.startsWith(queryWord)) {
        length = queryWord.length;
      }
    }
    if (length > 0) {
      ranges.add(TextRange(start: word.start, end: word.start + length));
    }
  }
  return ranges;
}

/// The entry's lower-cased name with its whitespace normalized, or `''` when
/// it has none.
String _name(LocalizedDesktopEntry entry) =>
    _words(entry.entries[DesktopEntryKey.name.string] ?? '').join(' ');

Iterable<String> _keywordWords(LocalizedDesktopEntry entry) =>
    entry.entries[DesktopEntryKey.keywords.string]?.getStringList().expand(
      _words,
    ) ??
    const [];

List<String> _words(String text) => text
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .toList();

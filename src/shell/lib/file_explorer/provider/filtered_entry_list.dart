import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/model/file_explorer_settings.dart';
import 'package:shell/file_explorer/model/file_kind.dart';
import 'package:shell/file_explorer/provider/directory_listing.dart';
import 'package:shell/file_explorer/provider/file_explorer_settings.dart';
import 'package:shell/file_explorer/provider/file_explorer_state.dart';
import 'package:shell/screen/model/screen.serializable.dart';

part 'filtered_entry_list.g.dart';

/// The current directory's entries, filtered by the search box, the hidden
/// files preference and the chooser's type filter, then sorted by the user's
/// sort preference.
@riverpod
AsyncValue<List<FileEntry>> filteredEntryList(Ref ref, ScreenId screenId) {
  final fileExplorer = ref.watch(fileExplorerStateProvider(screenId));
  final settings = ref.watch(fileExplorerSettingsProvider);
  final directoryListing = ref.watch(
    directoryListingProvider(fileExplorer.path),
  );

  return directoryListing.whenData(
    (entryList) => filterAndSortFileEntries(
      entryList,
      filterText: fileExplorer.filterText,
      settings: settings,
      typePatternList: fileExplorer.typePatternList,
      isDirectoryOnly: fileExplorer.isDirectoryOnly,
    ),
  );
}

/// Filters [entryList] by [filterText], the hidden-files preference, the
/// [typePatternList] and [isDirectoryOnly], then sorts it as [settings] asks.
List<FileEntry> filterAndSortFileEntries(
  List<FileEntry> entryList, {
  required String filterText,
  required FileExplorerSettings settings,
  List<String> typePatternList = const [],
  bool isDirectoryOnly = false,
}) {
  final normalizedFilter = filterText.toLowerCase();
  final typeMatcher = FileTypeMatcher(typePatternList);
  return entryList.where((entry) {
    if (!settings.showHidden && entry.isHidden) {
      return false;
    }
    if (!entry.isDirectory &&
        (isDirectoryOnly || !typeMatcher.matches(entry.name))) {
      return false;
    }
    if (normalizedFilter.isEmpty) {
      return true;
    }
    return entry.name.toLowerCase().contains(normalizedFilter);
  }).toList()..sort((a, b) => compareFileEntries(a, b, settings));
}

/// Orders two entries as [settings] asks: folders first when enabled, then
/// the sort key in the chosen direction, ties broken by natural name order.
int compareFileEntries(
  FileEntry a,
  FileEntry b,
  FileExplorerSettings settings,
) {
  if (settings.foldersFirst && a.isDirectory != b.isDirectory) {
    return a.isDirectory ? -1 : 1;
  }
  final byKey = switch (settings.sortBy) {
    FileSortKey.name => 0,
    FileSortKey.modified => _compareModified(a, b),
    FileSortKey.size =>
      a.isDirectory || b.isDirectory ? 0 : a.size.compareTo(b.size),
    FileSortKey.type => _compareType(a, b),
  };
  final result = byKey != 0 ? byKey : compareNaturally(a.name, b.name);
  return settings.sortDescending ? -result : result;
}

int _compareModified(FileEntry a, FileEntry b) {
  final aModified = a.modified;
  final bModified = b.modified;
  if (aModified == null || bModified == null) {
    return aModified == bModified ? 0 : (aModified == null ? -1 : 1);
  }
  return aModified.compareTo(bModified);
}

int _compareType(FileEntry a, FileEntry b) {
  final byKind = a.kind.index.compareTo(b.kind.index);
  if (byKind != 0) {
    return byKind;
  }
  return fileExtension(a.name).compareTo(fileExtension(b.name));
}

/// Case-insensitive "natural" comparison: runs of digits compare by value, so
/// `file2` sorts before `file10`.
int compareNaturally(String a, String b) {
  final aLower = a.toLowerCase();
  final bLower = b.toLowerCase();
  var i = 0;
  var j = 0;
  while (i < aLower.length && j < bLower.length) {
    final aIsDigit = _isDigit(aLower.codeUnitAt(i));
    final bIsDigit = _isDigit(bLower.codeUnitAt(j));
    if (aIsDigit && bIsDigit) {
      final aStart = i;
      final bStart = j;
      while (i < aLower.length && _isDigit(aLower.codeUnitAt(i))) {
        i++;
      }
      while (j < bLower.length && _isDigit(bLower.codeUnitAt(j))) {
        j++;
      }
      final aRun = aLower.substring(aStart, i).replaceFirst(_leadingZeros, '');
      final bRun = bLower.substring(bStart, j).replaceFirst(_leadingZeros, '');
      if (aRun.length != bRun.length) {
        return aRun.length.compareTo(bRun.length);
      }
      final byValue = aRun.compareTo(bRun);
      if (byValue != 0) {
        return byValue;
      }
      continue;
    }
    final byUnit = aLower.codeUnitAt(i).compareTo(bLower.codeUnitAt(j));
    if (byUnit != 0) {
      return byUnit;
    }
    i++;
    j++;
  }
  final byRemaining = (aLower.length - i).compareTo(bLower.length - j);
  // Names equal apart from case still get a stable, deterministic order.
  return byRemaining != 0 ? byRemaining : a.compareTo(b);
}

final _leadingZeros = RegExp('^0+(?=.)');

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

/// Matches file names against the portal chooser's filter patterns.
///
/// A pattern is either a glob (`*.png`, `*.[jJ][pP][gG]`), matched against
/// the whole name case-insensitively, or a MIME type (`image/png`,
/// `image/*`), approximated from the extension. A MIME type the shell cannot
/// map lists every file rather than hiding files it cannot judge.
class FileTypeMatcher {
  FileTypeMatcher(List<String> patternList)
    : _isUnrestricted =
          patternList.isEmpty ||
          patternList.any(
            (pattern) =>
                pattern.contains('/') && _extensionsForMime(pattern) == null,
          ),
      _regExpList = [
        for (final pattern in patternList)
          if (pattern.contains('/'))
            for (final extension in _extensionsForMime(pattern) ?? <String>[])
              RegExp(
                r'\.'
                '${RegExp.escape(extension)}'
                r'$',
                caseSensitive: false,
              )
          else
            _globToRegExp(pattern),
      ];

  final bool _isUnrestricted;
  final List<RegExp> _regExpList;

  bool matches(String name) =>
      _isUnrestricted || _regExpList.any((regExp) => regExp.hasMatch(name));
}

RegExp _globToRegExp(String glob) {
  final buffer = StringBuffer('^');
  var inClass = false;
  for (final char in glob.split('')) {
    if (inClass) {
      buffer.write(char == '\\' ? r'\\' : char);
      if (char == ']') {
        inClass = false;
      }
      continue;
    }
    switch (char) {
      case '*':
        buffer.write('.*');
      case '?':
        buffer.write('.');
      case '[':
        inClass = true;
        buffer.write('[');
      default:
        buffer.write(RegExp.escape(char));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString(), caseSensitive: false);
}

/// The extensions approximating [mime], or `null` when it is not known.
List<String>? _extensionsForMime(String mime) {
  final normalized = mime.toLowerCase();
  final family = switch (normalized) {
    'image/*' => FileKind.image,
    'video/*' => FileKind.video,
    'audio/*' => FileKind.audio,
    _ => null,
  };
  if (family != null) {
    return extensionsForFileKind(family).toList();
  }
  if (normalized == 'text/*') {
    return [
      ...extensionsForFileKind(FileKind.text),
      ...extensionsForFileKind(FileKind.code),
      'csv',
    ];
  }
  return _extensionsByMime[normalized];
}

const Map<String, List<String>> _extensionsByMime = {
  'application/pdf': ['pdf'],
  'application/zip': ['zip'],
  'application/json': ['json'],
  'application/xml': ['xml'],
  'application/x-tar': ['tar'],
  'application/gzip': ['gz', 'tgz'],
  'application/x-7z-compressed': ['7z'],
  'application/vnd.rar': ['rar'],
  'application/msword': ['doc'],
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': [
    'docx',
  ],
  'application/vnd.oasis.opendocument.text': ['odt'],
  'application/vnd.ms-excel': ['xls'],
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['xlsx'],
  'application/vnd.oasis.opendocument.spreadsheet': ['ods'],
  'text/plain': ['txt', 'log'],
  'text/markdown': ['md'],
  'text/csv': ['csv'],
  'text/html': ['html', 'htm'],
  'text/css': ['css'],
  'image/png': ['png'],
  'image/jpeg': ['jpg', 'jpeg'],
  'image/gif': ['gif'],
  'image/webp': ['webp'],
  'image/svg+xml': ['svg'],
  'image/bmp': ['bmp'],
  'image/tiff': ['tif', 'tiff'],
  'image/avif': ['avif'],
  'image/heic': ['heic'],
  'audio/mpeg': ['mp3'],
  'audio/flac': ['flac'],
  'audio/ogg': ['ogg', 'oga', 'opus'],
  'audio/wav': ['wav'],
  'video/mp4': ['mp4', 'm4v'],
  'video/webm': ['webm'],
  'video/x-matroska': ['mkv'],
};

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/model/file_explorer_settings.dart';
import 'package:shell/file_explorer/provider/directory_item_count.dart';
import 'package:shell/file_explorer/provider/file_opener.dart';
import 'package:shell/file_explorer/provider/filtered_entry_list.dart';
import 'package:shell/file_explorer/widget/file_entry_icon.dart';

FileEntry _directory(String name) => FileEntry(
  name: name,
  path: DirectoryPath('/dir/$name'),
  isDirectory: true,
  size: 0,
);

FileEntry _file(String name, {int size = 1, DateTime? modified}) => FileEntry(
  name: name,
  path: DirectoryPath('/dir/$name'),
  isDirectory: false,
  size: size,
  modified: modified,
);

const _showHidden = FileExplorerSettings(showHidden: true);

List<String> _names(List<FileEntry> entryList) =>
    entryList.map((entry) => entry.name).toList();

void main() {
  group('DirectoryPath', () {
    test('reports the root with no parent and no breadcrumb', () {
      const root = DirectoryPath('/');
      expect(root.name, '/');
      expect(root.parent, isNull);
      expect(root.breadcrumb, isEmpty);
    });

    test('exposes its name, parent and breadcrumb', () {
      const path = DirectoryPath('/home/user');
      expect(path.name, 'user');
      expect(path.parent, const DirectoryPath('/home'));
      expect(path.breadcrumb, [
        (name: 'home', path: const DirectoryPath('/home')),
        (name: 'user', path: const DirectoryPath('/home/user')),
      ]);
    });

    test('walks up to the root one segment at a time', () {
      const path = DirectoryPath('/home/user');
      expect(path.parent?.parent, const DirectoryPath('/'));
      expect(path.parent?.parent?.parent, isNull);
    });
  });

  group('filterAndSortFileEntries', () {
    test('sorts directories first, then by name', () {
      final entryList = [
        _file('zeta.txt'),
        _directory('Beta'),
        _file('alpha.txt'),
        _directory('Alpha'),
      ];
      final result = filterAndSortFileEntries(
        entryList,
        filterText: '',
        settings: _showHidden,
      );
      expect(result.map((entry) => entry.name), [
        'Alpha',
        'Beta',
        'alpha.txt',
        'zeta.txt',
      ]);
    });

    test('matches the filter case-insensitively on names', () {
      final entryList = [
        _file('Report.pdf'),
        _file('notes.txt'),
        _directory('reports'),
      ];
      final result = filterAndSortFileEntries(
        entryList,
        filterText: 'REPORT',
        settings: _showHidden,
      );
      expect(result.map((entry) => entry.name), ['reports', 'Report.pdf']);
    });

    test('hides dotfiles when hidden files are off', () {
      final entryList = [_file('.bashrc'), _file('visible.txt')];
      final result = filterAndSortFileEntries(
        entryList,
        filterText: '',
        settings: const FileExplorerSettings(),
      );
      expect(result.map((entry) => entry.name), ['visible.txt']);
    });

    test('keeps dotfiles when hidden files are on', () {
      final entryList = [_file('.bashrc'), _file('visible.txt')];
      final result = filterAndSortFileEntries(
        entryList,
        filterText: '',
        settings: _showHidden,
      );
      expect(result.map((entry) => entry.name), ['.bashrc', 'visible.txt']);
    });
  });

  group('sorting', () {
    final entryList = [
      _file('b.txt', size: 30, modified: DateTime(2026, 1, 3)),
      _directory('folder'),
      _file('a.png', size: 10, modified: DateTime(2026)),
      _file('c.md', size: 20, modified: DateTime(2026, 1, 2)),
    ];

    List<String> sorted(FileExplorerSettings settings) => _names(
      filterAndSortFileEntries(entryList, filterText: '', settings: settings),
    );

    test('sorts by modification date, newest last unless reversed', () {
      expect(sorted(const FileExplorerSettings(sortBy: FileSortKey.modified)), [
        'folder',
        'a.png',
        'c.md',
        'b.txt',
      ]);
      expect(
        sorted(
          const FileExplorerSettings(
            sortBy: FileSortKey.modified,
            sortDescending: true,
          ),
        ),
        // Folders stay first: reversing applies within each group.
        ['folder', 'b.txt', 'c.md', 'a.png'],
      );
    });

    test('sorts by size and by type', () {
      expect(sorted(const FileExplorerSettings(sortBy: FileSortKey.size)), [
        'folder',
        'a.png',
        'c.md',
        'b.txt',
      ]);
      // Images come before text files in the type order.
      expect(sorted(const FileExplorerSettings(sortBy: FileSortKey.type)), [
        'folder',
        'a.png',
        'c.md',
        'b.txt',
      ]);
    });

    test('mixes folders and files when folders first is off', () {
      expect(sorted(const FileExplorerSettings(foldersFirst: false)), [
        'a.png',
        'b.txt',
        'c.md',
        'folder',
      ]);
    });

    test('orders numbers naturally', () {
      final result = filterAndSortFileEntries(
        [_file('file10'), _file('file2'), _file('File1')],
        filterText: '',
        settings: const FileExplorerSettings(),
      );
      expect(_names(result), ['File1', 'file2', 'file10']);
    });
  });

  group('type filters', () {
    final entryList = [
      _directory('photos'),
      _file('cat.PNG'),
      _file('dog.jpg'),
      _file('notes.txt'),
    ];

    List<String> filtered(
      List<String> patterns, {
      bool directoryOnly = false,
    }) => _names(
      filterAndSortFileEntries(
        entryList,
        filterText: '',
        settings: const FileExplorerSettings(),
        typePatternList: patterns,
        isDirectoryOnly: directoryOnly,
      ),
    );

    test('globs match case-insensitively and keep folders', () {
      expect(filtered(['*.png']), ['photos', 'cat.PNG']);
      expect(filtered(['*.[jJ][pP][gG]', '*.txt']), [
        'photos',
        'dog.jpg',
        'notes.txt',
      ]);
    });

    test('MIME types are approximated from the extension', () {
      expect(filtered(['image/*']), ['photos', 'cat.PNG', 'dog.jpg']);
      expect(filtered(['image/jpeg']), ['photos', 'dog.jpg']);
      // An unknown MIME type hides nothing rather than guessing.
      expect(filtered(['application/x-unknown']), [
        'photos',
        'cat.PNG',
        'dog.jpg',
        'notes.txt',
      ]);
    });

    test('the folder picker lists folders only', () {
      expect(filtered(const [], directoryOnly: true), ['photos']);
    });
  });

  group('directoryItemCount', () {
    test('counts entries, dotfiles only when hidden files are shown', () async {
      final directory = Directory.systemTemp.createTempSync('veshell_count');
      addTearDown(() => directory.deleteSync(recursive: true));
      File('${directory.path}/a.txt').createSync();
      File('${directory.path}/.hidden').createSync();
      Directory('${directory.path}/sub').createSync();

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final path = DirectoryPath(directory.path);

      expect(
        await container.read(directoryItemCountProvider(path, false).future),
        2,
      );
      expect(
        await container.read(directoryItemCountProvider(path, true).future),
        3,
      );
    });
  });

  group('iconForFileEntry', () {
    test('uses a folder glyph for directories', () {
      expect(iconForFileEntry(_directory('docs')), MdiIcons.folder);
    });

    test('maps known extensions and falls back to a generic file glyph', () {
      expect(iconForFileEntry(_file('photo.png')), MdiIcons.fileImage);
      expect(iconForFileEntry(_file('archive.zip')), MdiIcons.folderZip);
      expect(iconForFileEntry(_file('mystery')), MdiIcons.file);
      expect(iconForFileEntry(_file('.gitignore')), MdiIcons.file);
    });
  });

  group('openFileWithDefaultHandler', () {
    test('uses xdg-open when it is available', () async {
      final callList = <(String, String)>[];
      final didOpen = await openFileWithDefaultHandler(
        const DirectoryPath('/tmp/file.txt'),
        startProcess: (executable, arguments) async {
          callList.add((executable, arguments.join(' ')));
          return executable == 'xdg-open';
        },
      );
      expect(didOpen, isTrue);
      expect(callList, [('xdg-open', '/tmp/file.txt')]);
    });

    test('falls back to gio open when xdg-open is missing', () async {
      final callList = <(String, String)>[];
      final didOpen = await openFileWithDefaultHandler(
        const DirectoryPath('/tmp/file.txt'),
        startProcess: (executable, arguments) async {
          callList.add((executable, arguments.join(' ')));
          return executable == 'gio';
        },
      );
      expect(didOpen, isTrue);
      expect(callList, [
        ('xdg-open', '/tmp/file.txt'),
        ('gio', 'open /tmp/file.txt'),
      ]);
    });

    test('reports failure when no launcher can be started', () async {
      final callList = <(String, String)>[];
      final didOpen = await openFileWithDefaultHandler(
        const DirectoryPath('/tmp/file.txt'),
        startProcess: (executable, arguments) async {
          callList.add((executable, arguments.join(' ')));
          return false;
        },
      );
      expect(didOpen, isFalse);
      expect(callList.length, 2);
    });
  });
}

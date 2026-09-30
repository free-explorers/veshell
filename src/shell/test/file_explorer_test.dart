import 'package:flutter_test/flutter_test.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/provider/filtered_entry_list.dart';
import 'package:shell/file_explorer/widget/file_entry_icon.dart';

FileEntry _directory(String name) => FileEntry(
  name: name,
  path: DirectoryPath('/dir/$name'),
  isDirectory: true,
  size: 0,
);

FileEntry _file(String name) => FileEntry(
  name: name,
  path: DirectoryPath('/dir/$name'),
  isDirectory: false,
  size: 1,
);

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
        isShowingHidden: true,
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
        isShowingHidden: true,
      );
      expect(result.map((entry) => entry.name), ['reports', 'Report.pdf']);
    });

    test('hides dotfiles when hidden files are off', () {
      final entryList = [_file('.bashrc'), _file('visible.txt')];
      final result = filterAndSortFileEntries(
        entryList,
        filterText: '',
        isShowingHidden: false,
      );
      expect(result.map((entry) => entry.name), ['visible.txt']);
    });

    test('keeps dotfiles when hidden files are on', () {
      final entryList = [_file('.bashrc'), _file('visible.txt')];
      final result = filterAndSortFileEntries(
        entryList,
        filterText: '',
        isShowingHidden: true,
      );
      expect(result.map((entry) => entry.name), ['.bashrc', 'visible.txt']);
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
}

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shell/settings/provider/util/theme_detection.dart';

/// Icon names tried, in order, to represent a theme in the picker.
///
/// `folder` is part of the freedesktop naming spec and is the one icon every
/// complete theme ships; the others only cover themes that rename it.
const iconThemePreviewNames = ['folder', 'inode-directory', 'user-home'];

/// The file [theme] would paint for its preview icon, or `null`.
///
/// This is a narrow version of the freedesktop lookup: it only reads the
/// `index.theme` files of [theme] and its parents, then checks a few paths.
/// Indexing every installed theme just to draw one icon each would take
/// seconds on large themes such as Papirus.
File? findIconThemePreview(
  String theme, {
  List<String> names = iconThemePreviewNames,
  int size = 32,
  List<String>? baseDirectories,
}) {
  final bases = baseDirectories ?? iconThemeBaseDirectories();
  final chain = <_ThemeIndex>[];
  _collectThemeChain(theme, bases, chain, <String>{});

  for (final name in names) {
    for (final index in chain) {
      final icon = index.find(name, size, bases);
      if (icon != null) return icon;
    }
  }
  return null;
}

/// Depth-first `Inherits` order, as the freedesktop spec describes it.
///
/// `hicolor` is left out: it is only the shared fallback for application
/// icons and would make every theme borrow the same preview.
void _collectThemeChain(
  String theme,
  List<String> bases,
  List<_ThemeIndex> chain,
  Set<String> visited,
) {
  if (theme == 'hicolor' || !visited.add(theme)) return;
  final index = _ThemeIndex.read(theme, bases);
  if (index == null) return;
  chain.add(index);
  for (final parent in index.inherits) {
    _collectThemeChain(parent, bases, chain, visited);
  }
}

class _ThemeIndex {
  _ThemeIndex(this.name, this.inherits, this.directories);

  final String name;
  final List<String> inherits;
  final List<_IconDirectory> directories;

  static _ThemeIndex? read(String theme, List<String> bases) {
    for (final base in bases) {
      final file = File(path.join(base, theme, 'index.theme'));
      if (!file.existsSync()) continue;
      final sections = _parseIni(file.readAsLinesSync());
      final header = sections['Icon Theme'] ?? const {};
      final directories = [
        for (final directory in _list(header['Directories']))
          if (sections[directory] case final keys?)
            _IconDirectory.fromKeys(directory, keys),
      ];
      return _ThemeIndex(theme, _list(header['Inherits']), directories);
    }
    return null;
  }

  File? find(String icon, int size, List<String> bases) {
    // Unscaled directories first, then the closest size.
    final ordered = [...directories]
      ..sort((a, b) {
        final byScale = (a.scale == 1 ? 0 : 1).compareTo(b.scale == 1 ? 0 : 1);
        if (byScale != 0) return byScale;
        return a.distance(size).compareTo(b.distance(size));
      });
    for (final directory in ordered) {
      for (final base in bases) {
        for (final extension in const ['svg', 'png']) {
          final file = File(
            path.join(base, name, directory.path, '$icon.$extension'),
          );
          if (file.existsSync()) return file;
        }
      }
    }
    return null;
  }
}

class _IconDirectory {
  _IconDirectory({
    required this.path,
    required this.size,
    required this.scale,
    required this.type,
    required this.minSize,
    required this.maxSize,
    required this.threshold,
  });

  factory _IconDirectory.fromKeys(String path, Map<String, String> keys) {
    final size = int.tryParse(keys['Size'] ?? '') ?? 48;
    return _IconDirectory(
      path: path,
      size: size,
      scale: int.tryParse(keys['Scale'] ?? '') ?? 1,
      type: keys['Type'] ?? 'Threshold',
      minSize: int.tryParse(keys['MinSize'] ?? '') ?? size,
      maxSize: int.tryParse(keys['MaxSize'] ?? '') ?? size,
      threshold: int.tryParse(keys['Threshold'] ?? '') ?? 2,
    );
  }

  final String path;
  final int size;
  final int scale;
  final String type;
  final int minSize;
  final int maxSize;
  final int threshold;

  /// `DirectorySizeDistance` from the freedesktop icon theme spec.
  int distance(int target) {
    final (low, high) = switch (type) {
      'Fixed' => (size, size),
      'Scalable' => (minSize, maxSize),
      _ => (size - threshold, size + threshold),
    };
    if (target < low) return low - target;
    if (target > high) return target - high;
    return 0;
  }
}

List<String> _list(String? value) => [
  for (final item in (value ?? '').split(','))
    if (item.trim().isNotEmpty) item.trim(),
];

Map<String, Map<String, String>> _parseIni(List<String> lines) {
  final sections = <String, Map<String, String>>{};
  Map<String, String>? current;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      current = sections.putIfAbsent(
        trimmed.substring(1, trimmed.length - 1).trim(),
        () => {},
      );
      continue;
    }
    final separator = trimmed.indexOf('=');
    if (current == null || separator <= 0) continue;
    current[trimmed.substring(0, separator).trim()] = trimmed
        .substring(separator + 1)
        .trim();
  }
  return sections;
}

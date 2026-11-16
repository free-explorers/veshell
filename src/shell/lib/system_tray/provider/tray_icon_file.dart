import 'dart:io';

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';

part 'tray_icon_file.g.dart';

const _iconExtensions = ['svg', 'png'];

/// The file of the icon [name] at [size] physical pixels, or `null` when none
/// is found.
///
/// An absolute path is used as is. Otherwise the item's own [themePath]
/// (`IconThemePath`, where applications such as those built on
/// libappindicator write their icons) is searched first, then the icon theme.
@riverpod
Future<File?> trayIconFile(
  Ref ref,
  String name,
  String themePath,
  int size,
) async {
  if (p.isAbsolute(name)) {
    final file = File(name);
    return file.existsSync() ? file : null;
  }
  if (themePath.isNotEmpty) {
    final file = await _findInThemePath(themePath, name, size);
    if (file != null) return file;
  }
  return await ref.watch(
    iconFileFromQueryProvider(
      IconQuery(name: name, size: size, extensions: _iconExtensions),
    ).future,
  );
}

/// [name] in [themePath]: directly in it, or in a theme laid out under it
/// (`hicolor/22x22/apps/name.png`), preferring the smallest size that is at
/// least [size], then a scalable one.
Future<File?> _findInThemePath(String themePath, String name, int size) async {
  final directory = Directory(themePath);
  if (!directory.existsSync()) return null;
  for (final extension in _iconExtensions) {
    final file = File(p.join(themePath, '$name.$extension'));
    if (file.existsSync()) return file;
  }
  final candidates = <File>[];
  try {
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) continue;
      final basename = p.basename(entity.path);
      if (_iconExtensions.any((extension) => basename == '$name.$extension')) {
        candidates.add(entity);
      }
    }
  } on FileSystemException catch (_) {
    return null;
  }
  if (candidates.isEmpty) return null;
  int sizeOf(File file) {
    final match = RegExp(r'/(\d+)x\d+/').firstMatch(file.path);
    if (match != null) return int.parse(match.group(1)!);
    // A scalable icon fits any size.
    return file.path.endsWith('.svg') ? 1 << 20 : 0;
  }

  candidates.sort((a, b) => sizeOf(a).compareTo(sizeOf(b)));
  return candidates.firstWhere(
    (file) => sizeOf(file) >= size,
    orElse: () => candidates.last,
  );
}

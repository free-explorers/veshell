import 'dart:io';

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/icon_themes.dart';

part 'icon_file_from_query.g.dart';

/// Resolve the themed icon path without owning a decoded native image.
///
/// Kept alive on purpose. The resolved [File] is tiny — a reference per icon
/// and physical-size bucket — and the queries are bucketed (see
/// `iconPhysicalBucket`), so the family stays bounded by the installed apps.
/// In return, a widget that remounts (a page scrolled out of a `PageView`, a
/// launcher grid rebuilt on search) reads the path synchronously and starts
/// painting immediately instead of waiting on the filesystem lookup. The
/// decoded pixels are cached separately, by Flutter.
@Riverpod(keepAlive: true)
Future<File?> iconFileFromQuery(Ref ref, IconQuery query) async {
  final themes = await ref.watch(iconThemesProvider.future);
  return await themes.findIcon(query);
}

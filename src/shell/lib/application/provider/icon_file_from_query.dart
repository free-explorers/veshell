import 'dart:io';

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/icon_themes.dart';

part 'icon_file_from_query.g.dart';

/// Resolve the themed icon path without owning a decoded native image.
@riverpod
Future<File?> iconFileFromQuery(Ref ref, IconQuery query) async {
  final themes = await ref.watch(iconThemesProvider.future);
  return await themes.findIcon(query);
}

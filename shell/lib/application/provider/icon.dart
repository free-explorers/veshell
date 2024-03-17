import 'dart:io';

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/icon_themes.dart';

part 'icon.g.dart';

@Riverpod(keepAlive: true)
class IconForQuery extends _$IconForQuery {
  @override
  Future<File?> build(IconQuery query) async {
    final themes = await ref.watch(iconThemesProvider.future);
    return themes.findIcon(query);
  }
}

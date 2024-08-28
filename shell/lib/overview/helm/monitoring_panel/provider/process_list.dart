import 'dart:async';
import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'process_list.g.dart';

@riverpod
class ProcessList extends _$ProcessList {
  @override
  Future<ISet<int>> build() async {
    final timer = Timer.periodic(const Duration(seconds: 1), (Timer t) async {
      ref.invalidateSelf();
    });

    ref.onDispose(timer.cancel);

    return (await _getProcessList()).lock;
  }

  Future<Set<int>> _getProcessList() async {
    return Directory('/proc')
        .list(followLinks: false)
        .where((dir) => dir is Directory)
        .cast<Directory>()
        .where((dir) => int.tryParse(p.basename(dir.path)) != null)
        .map(
          (dir) => int.parse(p.basename(dir.path)),
        )
        .toSet();
  }
}

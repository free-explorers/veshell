import 'dart:async';
import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitor_panel/model/process_stat.dart';

part 'process_list.g.dart';

@riverpod
class ProcessList extends _$ProcessList {
  @override
  ISet<int> build() {
    Timer.periodic(const Duration(seconds: 1), (Timer t) async {
      final list = _getProcessList();
      if (list != state) {
        state = list;
      }
    });
    return _getProcessList();
  }

  ISet<int> _getProcessList() {
    return Directory('/proc')
        .listSync(followLinks: false)
        .whereType<Directory>()
        .where((dir) => int.tryParse(p.basename(dir.path)) != null)
        .map(
          (dir) => int.parse(p.basename(dir.path)),
        )
        .toISet();
  }
}

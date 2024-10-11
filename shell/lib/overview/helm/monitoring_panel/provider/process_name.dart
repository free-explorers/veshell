import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'process_name.g.dart';

@riverpod
class ProcessName extends _$ProcessName {
  @override
  String build(int pid) {
    final file = File('/proc/$pid/comm');
    if (file.existsSync()) {
      return file.readAsStringSync().trim();
    } else {
      return 'Unknown';
    }
  }
}

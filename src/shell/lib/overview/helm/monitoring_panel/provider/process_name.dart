import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'process_name.g.dart';

@riverpod
class ProcessName extends _$ProcessName {
  @override
  String build(int pid) {
    try {
      final name = File('/proc/$pid/comm').readAsStringSync().trim();
      if (name.isNotEmpty) return name;
    } on FileSystemException {
      // The process may have exited between the listing and this read.
    }
    return 'pid $pid';
  }
}

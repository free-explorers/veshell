import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'process_name.g.dart';

@riverpod
String ProcessName(ProcessNameRef ref, int pid) {
  final file = File('/proc/$pid/comm');
  if (file.existsSync()) {
    return file.readAsStringSync().trim();
  } else {
    return 'Unknown';
  }
}

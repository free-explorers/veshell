import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'process_name.g.dart';

@riverpod
String ProcessName(ProcessNameRef ref, int pid) {
  return File('/proc/$pid/comm').readAsStringSync().trim();
}

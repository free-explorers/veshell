import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'now_date_time.g.dart';

@riverpod
DateTime NowDateTime(NowDateTimeRef ref) {
  Timer.periodic(const Duration(seconds: 1), (_) {
    ref.invalidateSelf();
  });
  return DateTime.now();
}

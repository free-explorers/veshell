import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'now_date_time.g.dart';

@riverpod
DateTime NowDateTime(Ref ref) {
  Timer.periodic(const Duration(seconds: 1), (_) {
    if (ref.mounted) ref.invalidateSelf();
  });
  return DateTime.now();
}

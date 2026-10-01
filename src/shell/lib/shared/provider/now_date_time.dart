import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'now_date_time.g.dart';

@riverpod
DateTime NowDateTime(Ref ref) {
  final timer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (ref.mounted) ref.invalidateSelf();
  });
  // Cancel on every rebuild: `invalidateSelf` reruns `build`, and without this
  // each refresh leaked the previous periodic timer.
  ref.onDispose(timer.cancel);
  return DateTime.now();
}

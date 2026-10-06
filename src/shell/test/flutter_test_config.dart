import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Providers which observe platform locale changes need the binding even in
  // non-widget tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  await testMain();
}

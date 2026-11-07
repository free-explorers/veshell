import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/provider/cursor_transition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('holds cursor updates across a slide and settles just after it', () {
    final calls = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.mouseCursor, (call) async {
          if (call.method == 'setCursorTransitioning') {
            calls.add(call.arguments['transitioning'] as bool);
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.mouseCursor, null);
    });

    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cursorTransition = container.read(
        cursorTransitionProvider.notifier,
      );
      final token = Object();

      cursorTransition.begin(token);
      async.flushMicrotasks();
      expect(calls, [true]);

      cursorTransition.end(token);
      async.elapse(const Duration(milliseconds: 99));
      expect(calls, [true]);

      // The grace leaves room for the settled layout's cursor report, which
      // the embedder applies when the transition is released.
      async.elapse(const Duration(milliseconds: 2));
      async.flushMicrotasks();
      expect(calls, [true, false]);
    });
  });

  test('a new slide during the settle grace keeps the cursor held', () {
    final calls = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.mouseCursor, (call) async {
          if (call.method == 'setCursorTransitioning') {
            calls.add(call.arguments['transitioning'] as bool);
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.mouseCursor, null);
    });

    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cursorTransition = container.read(
        cursorTransitionProvider.notifier,
      );
      final first = Object();
      final second = Object();

      cursorTransition.begin(first);
      async.flushMicrotasks();
      cursorTransition.end(first);
      async.elapse(const Duration(milliseconds: 50));

      cursorTransition.begin(second);
      async.elapse(const Duration(milliseconds: 200));
      expect(calls, [true]);

      cursorTransition.end(second);
      async.elapse(const Duration(milliseconds: 101));
      async.flushMicrotasks();
      expect(calls, [true, false]);
    });
  });
}

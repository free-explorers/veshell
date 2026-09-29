import 'package:flutter_test/flutter_test.dart';
import 'package:shell/shared/util/relative_time.dart';

void main() {
  final now = DateTime.utc(2026, 9, 29, 12);

  String at(Duration age) => formatRelativeTime(
        now.subtract(age),
        localeName: 'en_US',
        now: now,
      );

  group('formatRelativeTime', () {
    test('reads Now under a minute', () {
      expect(at(Duration.zero), 'Now');
      expect(at(const Duration(seconds: 59)), 'Now');
    });

    test('pluralizes minutes', () {
      expect(at(const Duration(seconds: 60)), '1 minute ago');
      expect(at(const Duration(minutes: 5)), '5 minutes ago');
      expect(at(const Duration(minutes: 59)), '59 minutes ago');
    });

    test('pluralizes hours', () {
      expect(at(const Duration(hours: 1)), '1 hour ago');
      expect(at(const Duration(hours: 23)), '23 hours ago');
    });

    test('pluralizes days', () {
      expect(at(const Duration(days: 1)), '1 day ago');
      expect(at(const Duration(days: 6)), '6 days ago');
    });

    test('pluralizes weeks, months and years', () {
      expect(at(const Duration(days: 7)), '1 week ago');
      expect(at(const Duration(days: 34)), '4 weeks ago');
      expect(at(const Duration(days: 35)), '1 month ago');
      expect(at(const Duration(days: 364)), '12 months ago');
      expect(at(const Duration(days: 365)), '1 year ago');
      expect(at(const Duration(days: 730)), '2 years ago');
    });

    test('never emits a zero count (0 is "one" in some locales)', () {
      // Every unit branch is only reached with a count of at least one.
      for (final age in const [
        Duration(seconds: 60),
        Duration(hours: 1),
        Duration(days: 1),
        Duration(days: 7),
        Duration(days: 35),
        Duration(days: 365),
      ]) {
        expect(at(age), isNot(contains('0 ')));
      }
    });
  });
}

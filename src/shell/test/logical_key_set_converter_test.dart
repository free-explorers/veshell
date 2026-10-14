import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/shared/util/json_converter/logical_key_set.dart';

void main() {
  const converter = LogicalKeySetConverter();

  final superQ = LogicalKeySet.fromSet(<LogicalKeyboardKey>{
    LogicalKeyboardKey.superKey,
    LogicalKeyboardKey.keyQ,
  });
  final fnQ = LogicalKeySet.fromSet(<LogicalKeyboardKey>{
    LogicalKeyboardKey.fn,
    LogicalKeyboardKey.keyQ,
  });
  final fnOnly = LogicalKeySet.fromSet(<LogicalKeyboardKey>{
    LogicalKeyboardKey.fn,
  });

  group('fromJson', () {
    test('parses known keys', () {
      expect(converter.fromJson('super+q'), superQ);
    });

    test('parses the plain media play and pause keys', () {
      expect(
        converter.fromJson('mediaPlay'),
        LogicalKeySet.fromSet(<LogicalKeyboardKey>{
          LogicalKeyboardKey.mediaPlay,
        }),
      );
      expect(
        converter.fromJson('mediaPause'),
        LogicalKeySet.fromSet(<LogicalKeyboardKey>{
          LogicalKeyboardKey.mediaPause,
        }),
      );
    });

    test('throws on an empty or unknown value', () {
      expect(() => converter.fromJson(''), throwsException);
      expect(() => converter.fromJson('null'), throwsException);
      expect(() => converter.fromJson('super+bogus'), throwsException);
    });
  });

  group('toJson', () {
    test('round-trips known keys', () {
      expect(converter.fromJson(converter.toJson(superQ)), superQ);
    });

    test('drops keys without a known name', () {
      expect(converter.toJson(fnQ), 'q');
      expect(converter.toJson(fnOnly), '');
    });
  });

  group('LogicalKeySetListConverter', () {
    const list = LogicalKeySetListConverter();

    test('reads the legacy single-string form as a one-element list', () {
      expect(list.fromJson('super+q'), [superQ]);
    });

    test('reads the array form and drops unusable entries', () {
      expect(list.fromJson(['super+q', 'null', 42, '']), [superQ]);
    });

    test('a missing or empty value is an empty list', () {
      expect(list.fromJson(null), isEmpty);
      expect(list.fromJson(const <Object?>[]), isEmpty);
      expect(list.fromJson(42), isEmpty);
    });

    test('serializes as an array and skips unnamed chords', () {
      final serialized = list.toJson([fnQ, superQ])! as List;
      expect(serialized, hasLength(2));
      // `fn` has no name and is dropped, leaving `q`.
      expect(serialized[0], 'q');
      // Key order within a chord is not significant.
      expect(list.fromJson(serialized[1]), [superQ]);
      expect(list.toJson([fnOnly]), isEmpty);
    });
  });
}

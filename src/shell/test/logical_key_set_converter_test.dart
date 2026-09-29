import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/shared/util/json_converter/logical_key_set.dart';

void main() {
  const converter = LogicalKeySetConverter();

  final superQ = LogicalKeySet.fromSet(
    <LogicalKeyboardKey>{LogicalKeyboardKey.superKey, LogicalKeyboardKey.keyQ},
  );
  final fnQ = LogicalKeySet.fromSet(
    <LogicalKeyboardKey>{LogicalKeyboardKey.fn, LogicalKeyboardKey.keyQ},
  );
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
}

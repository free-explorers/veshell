import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/util/application_symbol.dart';

void main() {
  group('applicationSymbol', () {
    test('capitalizes the first letter and lowercases the second', () {
      expect(applicationSymbol('Files'), 'Fi');
      expect(applicationSymbol('alacritty'), 'Al');
      expect(applicationSymbol('GIMP'), 'Gi');
      expect(applicationSymbol('visual studio code'), 'Vi');
    });

    test('skips leading punctuation and separators', () {
      expect(applicationSymbol('  (Files)'), 'Fi');
      expect(applicationSymbol('“Spotify”'), 'Sp');
      expect(applicationSymbol('_terminal'), 'Te');
      expect(applicationSymbol('7-Zip'), '7z');
      expect(applicationSymbol('X 11'), 'X1');
    });

    test('handles non-ASCII letters', () {
      expect(applicationSymbol('Über'), 'Üb');
      expect(applicationSymbol('éCLAIR'), 'Éc');
    });

    test('keeps a leading digit', () {
      expect(applicationSymbol('1Password'), '1p');
    });

    test('keeps one character for a single letter or a caseless script', () {
      expect(applicationSymbol('X'), 'X');
      expect(applicationSymbol('微信'), '微');
    });

    test('falls back to the first character when there is no letter', () {
      expect(applicationSymbol(''), '?');
      expect(applicationSymbol('   '), '?');
      expect(applicationSymbol('★'), '★');
    });
  });
}

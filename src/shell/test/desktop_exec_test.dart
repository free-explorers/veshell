import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/model/desktop_exec.dart';

void main() {
  test('parses quoted arguments and escapes', () {
    final exec = DesktopExec.parse(
      r'code --new-window "%f" env FOO="bar baz" name\ with\ space',
    );

    expect(exec.tokens, [
      'code',
      '--new-window',
      '%f',
      'env',
      'FOO=bar baz',
      'name with space',
    ]);
    expect(exec.hasFileFieldCode, isTrue);
  });

  test('supports single quotes used by entries in the wild', () {
    expect(DesktopExec.parse(r"app 'two words' %U").tokens, [
      'app',
      'two words',
      '%U',
    ]);
  });

  test('keeps empty quoted arguments', () {
    expect(DesktopExec.parse('app "" %f').tokens, ['app', '', '%f']);
  });

  test('detects every document field code', () {
    for (final code in ['%f', '%F', '%u', '%U']) {
      expect(DesktopExec.parse('app $code').hasFileFieldCode, isTrue);
    }
    for (final code in ['%i', '%c', '%k', '%%']) {
      expect(DesktopExec.parse('app $code').hasFileFieldCode, isFalse);
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/model/terminal_program_policy.dart';

void main() {
  group('isSafeTerminalProgram', () {
    test(
      'allows editors, pagers, monitors, file managers and multiplexers',
      () {
        for (final program in [
          'nvim',
          'vim',
          'less',
          'htop',
          'ranger',
          'tmux',
          '/usr/bin/nvim',
          'batcat',
        ]) {
          expect(isSafeTerminalProgram(program), isTrue, reason: program);
        }
      },
    );

    test('never replays shells, remote sessions, privilege or build tools', () {
      for (final program in [
        'bash',
        'zsh',
        '/bin/sh',
        'ssh',
        'sudo',
        'doas',
        'make',
        'cargo',
        'python3',
        'apt',
        'unknown-script',
      ]) {
        expect(isSafeTerminalProgram(program), isFalse, reason: program);
      }
    });
  });

  test('recognizes shells for the surviving prompt', () {
    expect(isTerminalShell('/usr/bin/bash'), isTrue);
    expect(isTerminalShell('fish'), isTrue);
    expect(isTerminalShell('/usr/bin/htop'), isFalse);
  });

  group('resolveExecutablePath', () {
    test('accepts an absolute executable', () {
      expect(
        resolveExecutablePath(
          '/usr/bin/htop',
          isExecutable: (path) => path == '/usr/bin/htop',
        ),
        '/usr/bin/htop',
      );
    });

    test('resolves a bare name through PATH', () {
      expect(
        resolveExecutablePath(
          'htop',
          environment: {'PATH': '/bin:/usr/bin'},
          isExecutable: (path) => path == '/usr/bin/htop',
        ),
        '/usr/bin/htop',
      );
    });

    test('returns null when the program is missing or not executable', () {
      expect(
        resolveExecutablePath('/usr/bin/htop', isExecutable: (_) => false),
        isNull,
      );
      expect(
        resolveExecutablePath(
          'missing',
          environment: {'PATH': '/bin'},
          isExecutable: (_) => false,
        ),
        isNull,
      );
    });
  });
}

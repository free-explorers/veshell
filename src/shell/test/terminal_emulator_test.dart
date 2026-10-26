import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/model/terminal_emulator.dart';

void main() {
  group('terminalEmulatorFor', () {
    test('detects native terminals from the executable', () {
      expect(
        terminalEmulatorFor(executable: '/usr/bin/alacritty')?.name,
        'alacritty',
      );
      expect(terminalEmulatorFor(executable: '/usr/bin/foot')?.name, 'foot');
      expect(
        terminalEmulatorFor(executable: '/usr/bin/wezterm')?.name,
        'wezterm',
      );
    });

    test('detects from the desktop Exec template', () {
      expect(
        terminalEmulatorFor(execTemplate: 'kitty --single-instance')?.name,
        'kitty',
      );
      expect(
        terminalEmulatorFor(
          execTemplate: 'env TERM=xterm-256color xterm',
        )?.name,
        'xterm',
      );
    });

    test('skips flatpak and snap wrappers', () {
      expect(
        terminalEmulatorFor(
          execTemplate: 'flatpak run org.gnome.Console',
        )?.name,
        'kgx',
      );
      expect(
        terminalEmulatorFor(execTemplate: 'snap run wezterm')?.name,
        'wezterm',
      );
    });

    test('detects from the application id', () {
      expect(
        terminalEmulatorFor(appId: 'org.gnome.Terminal')?.name,
        'gnome-terminal',
      );
    });

    test('returns null for an unknown terminal', () {
      expect(terminalEmulatorFor(execTemplate: 'mysteryterm'), isNull);
    });

    test('does not guess through a shell wrapper', () {
      expect(terminalEmulatorFor(execTemplate: 'sh -c "foot"'), isNull);
    });
  });

  group('command construction', () {
    test('foot uses -- and its working-directory flag', () {
      final foot = terminalEmulatorFor(executable: 'foot')!;
      expect(foot.commandArguments('/home/user/src'), [
        '--working-directory',
        '/home/user/src',
        '--',
      ]);
    });

    test('alacritty uses -e', () {
      final alacritty = terminalEmulatorFor(executable: 'alacritty')!;
      expect(alacritty.commandArguments(null), ['-e']);
    });

    test('wezterm uses start -- and --cwd', () {
      final wezterm = terminalEmulatorFor(executable: 'wezterm')!;
      expect(wezterm.commandArguments('/home/user/src'), [
        'start',
        '--cwd',
        '/home/user/src',
        '--',
      ]);
      expect(wezterm.suffixArguments('/home/user/src'), [
        '--cwd',
        '/home/user/src',
        '--',
      ]);
    });

    test('detects an already supplied terminal command separator', () {
      final alacritty = terminalEmulatorFor(executable: 'alacritty')!;
      expect(
        alacritty.hasCommandArguments(['alacritty', '-e', 'bash']),
        isTrue,
      );
      expect(
        alacritty.hasCommandArguments(['alacritty', '--class', 'x']),
        isFalse,
      );
    });
  });
}

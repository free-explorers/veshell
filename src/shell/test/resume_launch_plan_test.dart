import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/model/resume_launch_plan.dart';
import 'package:shell/window/model/resume_context.serializable.dart';

ResumeLaunchPlan? plan({
  required Set<String> existing,
  String? cwd,
  List<String> argv = const [],
  String? executable,
  TerminalResumeContext? terminal,
  String? customExec,
  String? execTemplate = 'app %U',
  String? entryName = 'App',
  String? entryIcon = 'app',
  String? appId,
  String? savedTitle,
  String? steamAppId,
  WineResumeContext? wine,
  bool Function(String path)? isExecutable,
}) {
  return buildResumeLaunchPlan(
    context: ResumeContext(
      workingDirectory: cwd,
      argv: argv,
      executable: executable,
      terminal: terminal,
      steamAppId: steamAppId,
      wine: wine,
    ),
    customExec: customExec,
    execTemplate: execTemplate,
    entryName: entryName,
    entryIcon: entryIcon,
    homeDirectory: '/home/user',
    appId: appId,
    savedTitle: savedTitle,
    environment: const {'SHELL': '/usr/bin/bash', 'PATH': '/usr/bin'},
    pathExists: existing.contains,
    isExecutable: isExecutable ?? (_) => true,
  );
}

const _bash = TerminalResumeContext(shell: '/usr/bin/bash');

const _survivalScript =
    r'if [ -n "$1" ]; then printf "\033]0;%s\007" "$1"; fi; '
    r'shift; "$@"; exec "$0"';

TerminalResumeContext terminalWith(ForegroundProgram foreground) =>
    TerminalResumeContext(
      shell: _bash.shell,
      workingDirectory: '/home/user/src',
      foreground: foreground,
    );

void main() {
  test('substitutes documents and applies the saved working directory', () {
    final result = plan(
      cwd: '/home/user/project',
      argv: ['app', '/home/user/project/report.pdf', '--new-window'],
      existing: {
        '/home/user/project',
        '/home/user',
        '/home/user/project/report.pdf',
      },
    )!;

    expect(result.config.workingDirectory, '/home/user/project');
    expect(result.config.argv, [
      'app',
      'file:///home/user/project/report.pdf',
      '--new-window',
    ]);
    expect(result.config.command, isNull);
  });

  test('keeps non-file argument order when the template has no field code', () {
    final result = plan(
      execTemplate: 'app --new-window',
      argv: ['app', '--flag', '/home/user/doc.txt', '--last'],
      existing: {'/home/user', '/home/user/doc.txt'},
    )!;

    expect(result.config.argv, [
      'app',
      '--new-window',
      '--flag',
      '/home/user/doc.txt',
      '--last',
    ]);
  });

  group('a process that is not the entry program', () {
    // Zotero's `zotero` script runs
    // `zotero-bin -app /usr/lib/zotero/application.ini "$@"` (#277).
    const zoteroArgv = [
      '/usr/lib/zotero/zotero-bin',
      '-app',
      '/usr/lib/zotero/application.ini',
    ];

    test("does not hand the inner binary's files to the entry", () {
      final result = plan(
        execTemplate: 'zotero -url %U',
        argv: zoteroArgv,
        executable: '/usr/lib/zotero/zotero-bin',
        existing: {'/home/user', '/usr/lib/zotero/application.ini'},
      )!;

      expect(result.config.argv, ['zotero', '-url']);
    });

    test("keeps the user's documents but not the inner flags", () {
      final result = plan(
        execTemplate: '/usr/bin/libreoffice --writer %U',
        argv: [
          '/usr/lib/libreoffice/program/soffice.bin',
          '--writer',
          '/home/user/report.odt',
          '--splash-pipe=5',
        ],
        existing: {'/home/user', '/home/user/report.odt'},
      )!;

      expect(result.config.argv, [
        '/usr/bin/libreoffice',
        '--writer',
        'file:///home/user/report.odt',
      ]);
    });

    test('a flatpak wrapper cannot be compared and keeps only documents', () {
      final result = plan(
        execTemplate: 'flatpak run org.example.Editor @@u %U @@',
        argv: ['/app/bin/editor', '--gapplication-service', '/home/user/a.txt'],
        existing: {'/home/user', '/home/user/a.txt'},
      )!;

      expect(result.config.argv, [
        'flatpak',
        'run',
        'org.example.Editor',
        '@@u',
        'file:///home/user/a.txt',
        '@@',
      ]);
    });

    test('an env prefix still compares the program itself', () {
      final result = plan(
        execTemplate: 'env FOO=1 app %U',
        argv: ['/usr/bin/app', '--flag'],
        existing: {'/home/user'},
      )!;

      expect(result.config.argv, ['env', 'FOO=1', 'app', '--flag']);
    });

    test('the fallback still replays the captured process as it ran', () {
      final result = plan(
        execTemplate: null,
        argv: zoteroArgv,
        existing: {'/home/user', '/usr/lib/zotero/application.ini'},
      )!;

      expect(result.config.argv, zoteroArgv);
    });
  });

  test('drops a missing document instead of failing the launch', () {
    final result = plan(
      cwd: '/home/user',
      argv: ['app', '/home/user/missing.pdf', '--flag'],
      existing: {'/home/user'},
    )!;

    expect(result.config.argv, ['app', '--flag']);
  });

  test('falls back to home when the saved directory is gone', () {
    final result = plan(cwd: '/gone', argv: ['app'], existing: {'/home/user'})!;

    expect(result.config.workingDirectory, '/home/user');
  });

  test('falls back to the captured argv when the entry is gone', () {
    final result = plan(
      execTemplate: null,
      cwd: '/home/user/src',
      argv: ['/usr/bin/app', '--flag', '/home/user/src/file.txt'],
      existing: {'/home/user/src', '/home/user', '/home/user/src/file.txt'},
    )!;

    expect(result.config.argv, [
      '/usr/bin/app',
      '--flag',
      '/home/user/src/file.txt',
    ]);
  });

  test('falls back to the executable when no argv was captured', () {
    final result = plan(
      execTemplate: null,
      executable: '/usr/bin/app',
      existing: {'/home/user'},
    )!;

    expect(result.config.argv, ['/usr/bin/app']);
  });

  test('custom exec is an Exec line and keeps the cwd', () {
    final result = plan(
      cwd: '/home/user/src',
      customExec: 'nvim .',
      existing: {'/home/user/src', '/home/user'},
    )!;

    expect(result.config.argv, ['nvim', '.']);
    expect(result.config.command, isNull);
    expect(result.config.workingDirectory, '/home/user/src');
  });

  test('custom exec fills its field codes from the saved documents', () {
    final result = plan(
      customExec: 'app --private %U',
      argv: ['app', '/home/user/report.pdf'],
      existing: {'/home/user', '/home/user/report.pdf'},
    )!;

    expect(result.config.argv, [
      'app',
      '--private',
      'file:///home/user/report.pdf',
    ]);
  });

  test("a custom exec without the wrapper's arguments drops them", () {
    // #277: editing Zotero's command must not bring `application.ini` back.
    final result = plan(
      customExec: 'zotero',
      argv: [
        '/usr/lib/zotero/zotero-bin',
        '-app',
        '/usr/lib/zotero/application.ini',
      ],
      executable: '/usr/lib/zotero/zotero-bin',
      existing: {'/home/user', '/usr/lib/zotero/application.ini'},
    )!;

    expect(result.config.argv, ['zotero']);
  });

  test('expands icon, name and literal percent codes', () {
    final result = plan(
      execTemplate: 'app %i %c %% %k',
      existing: {'/home/user'},
    )!;

    expect(result.config.argv, ['app', '--icon', 'app', 'App', '%']);
  });

  test('drops a file field code with no document', () {
    final result = plan(
      execTemplate: 'app %f --wait',
      existing: {'/home/user'},
    )!;

    expect(result.config.argv, ['app', '--wait']);
  });

  test('a terminal does not replay its emulator flags', () {
    final result = buildResumeLaunchPlan(
      context: const ResumeContext(
        workingDirectory: '/home/user/src',
        argv: ['foot', '--server', '/run/foot.sock'],
        terminal: TerminalResumeContext(
          shell: '/usr/bin/bash',
          workingDirectory: '/home/user/src',
        ),
      ),
      execTemplate: 'foot',
      homeDirectory: '/home/user',
      pathExists: {'/home/user/src', '/home/user'}.contains,
    )!;

    expect(result.config.argv, ['foot']);
    expect(result.config.workingDirectory, '/home/user/src');
  });

  test('a tile with no captured context keeps the compositor cwd', () {
    final result = buildResumeLaunchPlan(
      context: null,
      execTemplate: 'app',
      homeDirectory: '/home/user',
      pathExists: {'/home/user'}.contains,
    )!;

    expect(result.config.workingDirectory, isNull);
    expect(result.config.argv, ['app']);
  });

  test('returns null when there is no way to start anything', () {
    expect(plan(execTemplate: null, existing: {'/home/user'}), isNull);
  });

  test('file URIs are validated as local documents', () {
    final result = plan(
      execTemplate: 'app %u',
      argv: ['app', 'file:///home/user/report.pdf'],
      existing: {'/home/user', '/home/user/report.pdf'},
    )!;

    expect(result.config.argv, ['app', 'file:///home/user/report.pdf']);
  });

  test('%f converts a file URI to a path', () {
    final result = plan(
      execTemplate: 'app %f',
      argv: ['app', 'file:///home/user/report.pdf'],
      existing: {'/home/user', '/home/user/report.pdf'},
    )!;

    expect(result.config.argv, ['app', '/home/user/report.pdf']);
  });

  group('terminal foreground replay', () {
    test('runs an allowlisted program and keeps the shell', () {
      final result = plan(
        cwd: '/home/user/src',
        executable: '/usr/bin/foot',
        terminal: terminalWith(
          const ForegroundProgram(
            program: '/usr/bin/htop',
            arguments: ['-d', '10'],
          ),
        ),
        execTemplate: 'foot',
        appId: 'foot',
        savedTitle: 'htop',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv, [
        'foot',
        '--working-directory',
        '/home/user/src',
        '--',
        '/bin/sh',
        '-c',
        _survivalScript,
        '/usr/bin/bash',
        'htop',
        '/usr/bin/htop',
        '-d',
        '10',
      ]);
    });

    test('the saved title is seeded without terminal control characters', () {
      final result = plan(
        cwd: '/home/user/src',
        executable: '/usr/bin/foot',
        terminal: terminalWith(
          const ForegroundProgram(program: '/usr/bin/htop'),
        ),
        execTemplate: 'foot',
        appId: 'foot',
        savedTitle: 'htop\u001b]2;injected\u0007\n',
        existing: {'/home/user', '/home/user/src'},
      )!;

      final scriptIndex = result.config.argv.indexOf('-c') + 1;
      expect(result.config.argv[scriptIndex], _survivalScript);
      expect(result.config.argv[scriptIndex + 2], 'htop]2;injected');
    });

    test('a terminal-name title falls back to the program name', () {
      final result = plan(
        cwd: '/home/user/src',
        executable: '/usr/bin/alacritty',
        terminal: terminalWith(
          const ForegroundProgram(program: '/usr/bin/htop'),
        ),
        execTemplate: 'alacritty',
        appId: 'alacritty',
        savedTitle: 'Alacritty',
        existing: {'/home/user', '/home/user/src'},
      )!;

      final scriptIndex = result.config.argv.indexOf('-c') + 1;
      expect(result.config.argv[scriptIndex + 2], 'htop');
    });

    test('xterm uses -e', () {
      final result = plan(
        cwd: '/home/user/src',
        executable: '/usr/bin/xterm',
        terminal: terminalWith(
          const ForegroundProgram(
            program: '/usr/bin/nvim',
            arguments: ['file'],
          ),
        ),
        execTemplate: 'xterm',
        appId: 'xterm',
        savedTitle: 'nvim file',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv, [
        'xterm',
        '-e',
        '/bin/sh',
        '-c',
        _survivalScript,
        '/usr/bin/bash',
        'nvim file',
        '/usr/bin/nvim',
        'file',
      ]);
    });

    test('wezterm uses start --cwd and --', () {
      final result = plan(
        cwd: '/home/user/src',
        executable: '/usr/bin/wezterm',
        terminal: terminalWith(
          const ForegroundProgram(program: '/usr/bin/less'),
        ),
        execTemplate: 'wezterm',
        appId: 'wezterm',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv.take(6), [
        'wezterm',
        'start',
        '--cwd',
        '/home/user/src',
        '--',
        '/bin/sh',
      ]);
    });

    test('an unknown terminal does not guess a command syntax', () {
      final result = plan(
        cwd: '/home/user/src',
        terminal: terminalWith(
          const ForegroundProgram(program: '/usr/bin/htop'),
        ),
        execTemplate: 'mysteryterm',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv, ['mysteryterm']);
    });

    test('recovers the program from a wrapper saved by an older build', () {
      final result = plan(
        cwd: '/home/user/src',
        argv: [
          '/usr/bin/alacritty',
          '--working-directory',
          '/home/user/src',
          '-e',
          '/bin/sh',
          '-c',
          r'"$@"; exec "$0"',
          '/usr/bin/zsh',
          '/usr/bin/htop',
        ],
        executable: '/usr/bin/alacritty',
        terminal: const TerminalResumeContext(
          shell: '/usr/bin/bash',
          workingDirectory: '/home/user/src',
        ),
        execTemplate: 'alacritty',
        appId: 'alacritty',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv, [
        'alacritty',
        '--working-directory',
        '/home/user/src',
        '-e',
        '/bin/sh',
        '-c',
        _survivalScript,
        '/usr/bin/zsh',
        'htop',
        '/usr/bin/htop',
      ]);
    });

    test('a missing program leaves the terminal and shell only', () {
      final result = plan(
        cwd: '/home/user/src',
        executable: '/usr/bin/foot',
        terminal: terminalWith(
          const ForegroundProgram(program: '/usr/bin/htop'),
        ),
        execTemplate: 'foot',
        appId: 'foot',
        isExecutable: (path) => path != '/usr/bin/htop',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv, ['foot']);
    });

    test('custom exec without a command gets the foreground appended', () {
      final result = plan(
        cwd: '/home/user/src',
        executable: '/usr/bin/foot',
        terminal: terminalWith(
          const ForegroundProgram(program: '/usr/bin/htop'),
        ),
        customExec: 'foot',
        appId: 'foot',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv.take(5), [
        'foot',
        '--working-directory',
        '/home/user/src',
        '--',
        '/bin/sh',
      ]);
      expect(result.config.argv, contains('/usr/bin/htop'));
    });

    test('custom wezterm exec with its own start keeps one subcommand', () {
      final result = plan(
        cwd: '/home/user/src',
        executable: '/usr/bin/wezterm',
        terminal: terminalWith(
          const ForegroundProgram(program: '/usr/bin/htop'),
        ),
        customExec: 'wezterm start --always-new-process',
        appId: 'wezterm',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv.take(6), [
        'wezterm',
        'start',
        '--always-new-process',
        '--cwd',
        '/home/user/src',
        '--',
      ]);
    });

    test('custom exec with its own command separator is left alone', () {
      final result = plan(
        cwd: '/home/user/src',
        executable: '/usr/bin/alacritty',
        terminal: terminalWith(
          const ForegroundProgram(program: '/usr/bin/htop'),
        ),
        customExec: 'alacritty -e bash',
        appId: 'alacritty',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv, ['alacritty', '-e', 'bash']);
    });

    test('custom exec for a non-terminal never appends a program', () {
      final result = plan(
        cwd: '/home/user/src',
        terminal: terminalWith(
          const ForegroundProgram(program: '/usr/bin/htop'),
        ),
        customExec: 'nvim .',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv, ['nvim', '.']);
    });

    test('a stored non-allowlisted program is never replayed', () {
      final result = plan(
        cwd: '/home/user/src',
        executable: '/usr/bin/foot',
        terminal: terminalWith(
          const ForegroundProgram(program: '/usr/bin/ssh'),
        ),
        execTemplate: 'foot',
        appId: 'foot',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv, ['foot']);
    });

    test(r'falls back to $SHELL when the captured shell is missing', () {
      final result = plan(
        cwd: '/home/user/src',
        executable: '/usr/bin/foot',
        terminal: const TerminalResumeContext(
          foreground: ForegroundProgram(program: '/usr/bin/htop'),
        ),
        execTemplate: 'foot',
        appId: 'foot',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv, contains('/usr/bin/bash'));
    });

    test('drops the program when no surviving shell is usable', () {
      final result = plan(
        cwd: '/home/user/src',
        executable: '/usr/bin/foot',
        terminal: terminalWith(
          const ForegroundProgram(program: '/usr/bin/htop'),
        ),
        execTemplate: 'foot',
        appId: 'foot',
        isExecutable: (path) => path == '/usr/bin/htop',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv, ['foot']);
    });

    test('a terminal without a foreground keeps its normal entry launch', () {
      final result = plan(
        cwd: '/home/user/src',
        terminal: _bash,
        execTemplate: 'foot',
        existing: {'/home/user', '/home/user/src'},
      )!;

      expect(result.config.argv, ['foot']);
    });
  });

  test("follows the application's scope through its desktop id", () {
    final result = plan(
      argv: ['flatpak', 'run', 'com.rustdesk.RustDesk'],
      appId: 'com.rustdesk.RustDesk',
      existing: {'/home/user'},
    )!;

    expect(
      result.scope?.matches('app-flatpak-com.rustdesk.RustDesk-4242.scope'),
      isTrue,
    );
  });

  group('Proton games', () {
    const windowsArgv = [r'Z:\home\user\games\Game.exe', '-dx12'];

    test('relaunch through Steam instead of the Windows command line', () {
      final result = plan(
        argv: windowsArgv,
        executable: '/opt/Proton/files/bin/wine64-preloader',
        steamAppId: '1091500',
        execTemplate: null,
        existing: {'/home/user'},
        isExecutable: (path) => path == '/usr/bin/steam',
      )!;

      expect(result.config.argv, [
        '/usr/bin/steam',
        'steam://rungameid/1091500',
      ]);
    });

    test('win over a desktop entry, whose Exec cannot take the argv', () {
      final result = plan(
        argv: windowsArgv,
        steamAppId: '1091500',
        execTemplate: 'steam %U',
        existing: {'/home/user'},
        isExecutable: (path) => path == '/usr/bin/steam',
      )!;

      expect(result.config.argv, [
        '/usr/bin/steam',
        'steam://rungameid/1091500',
      ]);
    });

    test('use the steam: URI handler when steam is not on PATH', () {
      final result = plan(
        argv: windowsArgv,
        steamAppId: '1091500',
        existing: {'/home/user'},
        isExecutable: (_) => false,
      )!;

      expect(result.config.argv, ['xdg-open', 'steam://rungameid/1091500']);
    });

    test('name the scope Steam will start the game in', () {
      final result = plan(
        argv: windowsArgv,
        steamAppId: '1091500',
        existing: {'/home/user'},
      )!;

      expect(result.scope?.matches('app-steam-app1091500-77.scope'), isTrue);
      expect(result.scope?.matches('app-flatpak-app1091500-77.scope'), isFalse);
    });

    test('a custom exec still wins', () {
      final result = plan(
        argv: windowsArgv,
        steamAppId: '1091500',
        customExec: 'gamemoderun steam steam://rungameid/1091500',
        existing: {'/home/user'},
      )!;

      expect(result.scope?.launcher, isNull);
      expect(result.config.argv, [
        'gamemoderun',
        'steam',
        'steam://rungameid/1091500',
      ]);
    });
  });

  group('plain Wine programs', () {
    const windowsArgv = [r'C:\Games\App\App.exe', '-windowed'];
    const lutrisWine = '/home/user/.local/share/lutris/runners/wine/ge/bin';
    const wine = WineResumeContext(
      environment: {'WINEPREFIX': '/home/user/Games/app', 'DXVK_HUD': 'fps'},
    );

    test('run again through the Wine build and configuration they ran', () {
      final result = plan(
        cwd: '/home/user/Games/app/drive_c/Games/App',
        argv: windowsArgv,
        executable: '$lutrisWine/wine64-preloader',
        wine: wine,
        execTemplate: null,
        existing: {'/home/user', '/home/user/Games/app/drive_c/Games/App'},
        isExecutable: (path) => path == '$lutrisWine/wine',
      )!;

      expect(result.config.argv, [
        'env',
        'DXVK_HUD=fps',
        'WINEPREFIX=/home/user/Games/app',
        '$lutrisWine/wine',
        ...windowsArgv,
      ]);
      expect(
        result.config.workingDirectory,
        '/home/user/Games/app/drive_c/Games/App',
      );
    });

    test('use the Wine on PATH once their build is gone', () {
      final result = plan(
        argv: windowsArgv,
        executable: '$lutrisWine/wine64-preloader',
        wine: const WineResumeContext(),
        execTemplate: null,
        existing: {'/home/user'},
        isExecutable: (path) => path == '/usr/bin/wine',
      )!;

      expect(result.config.argv, ['/usr/bin/wine', ...windowsArgv]);
    });

    test("leave a desktop entry (Wine's own menu entry) in charge", () {
      final result = plan(
        argv: windowsArgv,
        executable: '$lutrisWine/wine64-preloader',
        wine: wine,
        execTemplate: r'env WINEPREFIX=/home/user/.wine wine C:\\App.exe',
        existing: {'/home/user'},
      )!;

      expect(result.config.argv.first, 'env');
      expect(result.config.argv, isNot(contains('DXVK_HUD=fps')));
    });

    test('replay the command line when no Wine is left at all', () {
      final result = plan(
        argv: windowsArgv,
        executable: '$lutrisWine/wine64-preloader',
        wine: wine,
        execTemplate: null,
        existing: {'/home/user'},
        isExecutable: (_) => false,
      )!;

      expect(result.config.argv.first, windowsArgv.first);
    });
  });
}

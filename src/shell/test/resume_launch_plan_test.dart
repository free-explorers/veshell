import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/model/resume_launch_plan.dart';
import 'package:shell/window/model/resume_context.serializable.dart';

ResumeLaunchPlan? plan({
  String? cwd,
  List<String> argv = const [],
  String? executable,
  String? customExec,
  String? execTemplate = 'app %U',
  String? entryName = 'App',
  String? entryIcon = 'app',
  required Set<String> existing,
}) {
  return buildResumeLaunchPlan(
    context: ResumeContext(
      workingDirectory: cwd,
      argv: argv,
      executable: executable,
    ),
    customExec: customExec,
    execTemplate: execTemplate,
    entryName: entryName,
    entryIcon: entryIcon,
    homeDirectory: '/home/user',
    pathExists: existing.contains,
  );
}

void main() {
  test('substitutes documents and applies the saved working directory', () {
    final result = plan(
      cwd: '/home/user/project',
      argv: ['code', '/home/user/project/report.pdf', '--new-window'],
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

  test('custom exec stays a shell command and keeps the cwd', () {
    final result = plan(
      cwd: '/home/user/src',
      customExec: 'nvim .',
      execTemplate: 'app %U',
      existing: {'/home/user/src', '/home/user'},
    )!;

    expect(result.config.command, 'nvim .');
    expect(result.config.argv, isEmpty);
    expect(result.config.workingDirectory, '/home/user/src');
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
}

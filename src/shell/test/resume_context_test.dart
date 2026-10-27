import 'package:flutter_test/flutter_test.dart';
import 'package:shell/platform/model/event/process_info/process_info.serializable.dart';
import 'package:shell/window/model/resume_context.serializable.dart';
import 'package:shell/window/provider/resume_context_capture.dart';
import 'package:shell/window/widget/resume_context_summary.dart';

void main() {
  group('captureResumeContextFromProcessInfo', () {
    test('captures command line, cwd and executable', () {
      final info = ProcessInfoMessage(
        pid: 42,
        cgroup: '/user.slice/app.scope',
        cmdline: const ['/usr/bin/code', '/home/user/project'],
        cwd: '/home/user/project',
        exe: '/usr/bin/code',
      );

      final context = captureResumeContextFromProcessInfo(info)!;

      expect(context.workingDirectory, '/home/user/project');
      expect(context.argv, ['/usr/bin/code', '/home/user/project']);
      expect(context.executable, '/usr/bin/code');
      expect(context.terminal, isNull);
      expect(context.capturedAt, isNotNull);
    });

    test("prefers a terminal shell's cwd over the emulator process cwd", () {
      final info = ProcessInfoMessage(
        pid: 10,
        cmdline: const ['foot'],
        cwd: '/home/user',
        exe: '/usr/bin/foot',
        terminal: TerminalInfoMessage(
          shell: ProcessDescriptorMessage(
            pid: 11,
            cmdline: const ['bash'],
            cwd: '/home/user/src',
            exe: '/usr/bin/bash',
          ),
        ),
      );

      final context = captureResumeContextFromProcessInfo(info)!;

      expect(context.workingDirectory, '/home/user/src');
      expect(context.terminal?.shell, '/usr/bin/bash');
      expect(context.terminal?.workingDirectory, '/home/user/src');
    });

    test('captures an allowlisted foreground program', () {
      final info = ProcessInfoMessage(
        pid: 10,
        cmdline: const ['foot'],
        cwd: '/home/user',
        exe: '/usr/bin/foot',
        terminal: TerminalInfoMessage(
          shell: ProcessDescriptorMessage(
            pid: 11,
            cmdline: const ['bash'],
            cwd: '/home/user/src',
            exe: '/usr/bin/bash',
          ),
          foreground: ProcessDescriptorMessage(
            pid: 12,
            cmdline: const ['htop', '-d', '10'],
            cwd: '/home/user/src',
            exe: '/usr/bin/htop',
          ),
        ),
      );

      final context = captureResumeContextFromProcessInfo(
        info,
        isExecutable: (path) => path == '/usr/bin/htop',
      )!;

      expect(context.terminal?.foreground?.program, '/usr/bin/htop');
      expect(context.terminal?.foreground?.arguments, ['-d', '10']);
    });

    test('drops a foreground program that is not allowlisted', () {
      final info = ProcessInfoMessage(
        pid: 10,
        cmdline: const ['foot'],
        cwd: '/home/user',
        exe: '/usr/bin/foot',
        terminal: TerminalInfoMessage(
          shell: ProcessDescriptorMessage(
            pid: 11,
            cmdline: const ['bash'],
            cwd: '/home/user/src',
            exe: '/usr/bin/bash',
          ),
          foreground: ProcessDescriptorMessage(
            pid: 12,
            cmdline: const ['ssh', 'host'],
            exe: '/usr/bin/ssh',
          ),
        ),
      );

      final context = captureResumeContextFromProcessInfo(
        info,
        isExecutable: (_) => true,
      )!;

      expect(context.terminal, isNotNull);
      expect(context.terminal?.foreground, isNull);
      expect(context.workingDirectory, '/home/user/src');
    });

    test('drops an allowlisted program that is missing', () {
      final info = ProcessInfoMessage(
        pid: 10,
        terminal: TerminalInfoMessage(
          shell: ProcessDescriptorMessage(
            pid: 11,
            cmdline: const ['bash'],
            cwd: '/home/user/src',
            exe: '/usr/bin/bash',
          ),
          foreground: ProcessDescriptorMessage(
            pid: 12,
            cmdline: const ['htop'],
            exe: '/usr/bin/htop',
          ),
        ),
      );

      final context = captureResumeContextFromProcessInfo(
        info,
        isExecutable: (_) => false,
      )!;

      expect(context.terminal?.foreground, isNull);
    });

    test('returns null when /proc gave nothing useful', () {
      expect(captureResumeContextFromProcessInfo(null), isNull);
      expect(
        captureResumeContextFromProcessInfo(ProcessInfoMessage(pid: 1)),
        isNull,
      );
    });

    test('round-trips a terminal foreground through JSON', () {
      final context = ResumeContext(
        workingDirectory: '/home/user/src',
        argv: const ['foot'],
        executable: '/usr/bin/foot',
        terminal: const TerminalResumeContext(
          shell: '/usr/bin/bash',
          workingDirectory: '/home/user/src',
          foreground: ForegroundProgram(
            program: '/usr/bin/htop',
            arguments: ['-d', '10'],
          ),
        ),
      );

      final decoded = ResumeContext.fromJson(context.toJson());

      expect(decoded.terminal?.foreground?.program, '/usr/bin/htop');
      expect(decoded.terminal?.foreground?.arguments, ['-d', '10']);
    });

    test('compares contexts ignoring the capture timestamp', () {
      final first = ResumeContext(
        workingDirectory: '/home/user',
        argv: const ['app'],
        capturedAt: DateTime(2026),
      );
      final second = first.copyWith(capturedAt: DateTime(2027));
      final different = first.copyWith(workingDirectory: '/tmp');

      expect(sameResumeContext(first, second), isTrue);
      expect(sameResumeContext(first, different), isFalse);
      expect(sameResumeContext(null, null), isTrue);
      expect(sameResumeContext(first, null), isFalse);
    });
  });

  group('resumeContextSummary', () {
    test('describes a terminal directory and foreground program', () {
      final summary = resumeContextSummary(
        const ResumeContext(
          workingDirectory: '/home/user/src',
          terminal: TerminalResumeContext(
            workingDirectory: '/home/user/src',
            foreground: ForegroundProgram(program: '/usr/bin/nvim'),
          ),
        ),
        homeDirectory: '/home/user',
      );

      expect(summary, '~/src — nvim');
    });

    test('describes a document', () {
      final summary = resumeContextSummary(
        const ResumeContext(
          workingDirectory: '/home/user',
          argv: ['app', '/home/user/report.pdf'],
        ),
        homeDirectory: '/home/user',
      );

      expect(summary, 'report.pdf');
    });

    test('falls back to the title instead of the application cwd', () {
      expect(
        resumeContextSummary(
          const ResumeContext(workingDirectory: '/home/user/src'),
          title: 'Code - OSS',
          homeDirectory: '/home/user',
        ),
        'Code - OSS',
      );
      expect(
        resumeContextSummary(
          const ResumeContext(workingDirectory: '/home/user'),
          homeDirectory: '/home/user',
        ),
        isNull,
      );
      expect(resumeContextSummary(null, title: 'Mozilla'), 'Mozilla');
    });

    test('keeps a terminal directory even when the title is available', () {
      final summary = resumeContextSummary(
        const ResumeContext(
          workingDirectory: '/home/user',
          terminal: TerminalResumeContext(workingDirectory: '/home/user'),
        ),
        title: 'user@host:~',
        homeDirectory: '/home/user',
      );

      expect(summary, '~');
    });
  });
}

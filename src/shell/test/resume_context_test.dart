import 'package:flutter_test/flutter_test.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/platform/model/event/process_info/process_info.serializable.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/window_manager/matching_utils.dart';
import 'package:shell/window/model/resume_context.serializable.dart';
import 'package:shell/window/provider/resume_context_capture.dart';
import 'package:shell/window/widget/resume_context_summary.dart';

class _FakeWindow extends Window {
  const _FakeWindow();

  @override
  WindowId get windowId => const WindowId.persistent('tile');

  @override
  WindowProperties get properties => const WindowProperties(appId: 'foot');

  @override
  MetaWindowId? get metaWindowId => null;
}

void main() {
  group('captureResumeContextFromProcessInfo', () {
    test('captures command line, cwd and cgroup', () {
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
      expect(context.cgroup, '/user.slice/app.scope');
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

    test('returns null when /proc gave nothing useful', () {
      expect(captureResumeContextFromProcessInfo(null), isNull);
      expect(
        captureResumeContextFromProcessInfo(ProcessInfoMessage(pid: 1)),
        isNull,
      );
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

  group('sameResumeGroup', () {
    test('groups by app id first', () {
      expect(
        sameResumeGroup(
          appIdA: 'foot',
          appIdB: 'foot',
          cgroupA: '/a',
          cgroupB: '/b',
        ),
        isTrue,
      );
    });

    test('groups different ids that share a saved cgroup', () {
      expect(
        sameResumeGroup(
          appIdA: 'steam',
          appIdB: 'steamwebhelper',
          cgroupA: '/launch',
          cgroupB: '/launch',
        ),
        isTrue,
      );
    });

    test('never groups unrelated empty ids', () {
      expect(
        sameResumeGroup(appIdA: '', appIdB: '', cgroupA: null, cgroupB: null),
        isFalse,
      );
    });
  });

  test('the clicked tile outranks an armed sibling in the launch gather', () {
    final now = DateTime.now();
    final clicked = MatchingInfo(appId: 'foot', waitingForAppSince: now);
    final sibling = MatchingInfo(
      appId: 'foot',
      waitingForAppSince: now,
      waitingPenalty: 25,
    );
    const metaWindow = MatchingInfo(appId: 'foot');
    const window = _FakeWindow();

    final clickedCost = windowMatchingCost(metaWindow, clicked, window).total;
    final siblingCost = windowMatchingCost(metaWindow, sibling, window).total;

    expect(clickedCost, lessThan(siblingCost));
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

    test('falls back to the cwd, then the title', () {
      expect(
        resumeContextSummary(
          const ResumeContext(workingDirectory: '/home/user/src'),
          homeDirectory: '/home/user',
        ),
        '~/src',
      );
      expect(resumeContextSummary(null, title: 'Mozilla'), 'Mozilla');
    });
  });
}

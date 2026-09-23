import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/logs_for_pid.dart';

/// Renders a launched process' captured output as a terminal transcript.
///
/// The launch command is echoed with a shell prompt, the application's
/// stdout/stderr follows, and a blinking block cursor sits at the very end so
/// the placeholder reads like a session started from a terminal.
class LogsViewer extends HookConsumerWidget {
  const LogsViewer({required this.pid, super.key});

  final int pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(logsForPidProvider(pid));
    final scrollController = useScrollController();
    final cursorVisible = useState(true);

    useEffect(() {
      final timer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => cursorVisible.value = !cursorVisible.value,
      );
      return timer.cancel;
    }, []);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.jumpTo(scrollController.position.maxScrollExtent);
        }
      });
      return null;
    }, [logs]);

    final textStyle =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
          fontFamily: 'monospace',
          height: 1.4,
        );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        controller: scrollController,
        child: SelectableText.rich(
          TextSpan(
            children: [
              TextSpan(text: logs.join()),
              TextSpan(
                text: '█',
                style: TextStyle(
                  color: cursorVisible.value
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                ),
              ),
            ],
          ),
          style: textStyle,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logs_for_pid.g.dart';

/// Maximum number of captured output characters kept per process.
///
/// The transcript is a debugging convenience: without a cap, a chatty process
/// would grow the shell's heap for as long as it runs.
const int maxLogCharacters = 256 * 1024;

/// Captured output of a launched process, plus whether that process is still
/// running. The liveness flag lets the log view stop drawing the cursor once
/// the process has exited.
class LogsForPidState {
  const LogsForPidState({this.lines = const [], this.isRunning = false});

  final List<String> lines;
  final bool isRunning;

  LogsForPidState copyWith({List<String>? lines, bool? isRunning}) =>
      LogsForPidState(
        lines: lines ?? this.lines,
        isRunning: isRunning ?? this.isRunning,
      );
}

@Riverpod(keepAlive: true)
class LogsForPid extends _$LogsForPid {
  /// Characters currently held in the captured lines, so trimming stays O(1)
  /// amortized instead of re-measuring the whole buffer on every chunk.
  int _characterCount = 0;

  @override
  LogsForPidState build(int pid) {
    _characterCount = 0;
    return const LogsForPidState();
  }

  void setProcess(Process process, {String? command}) {
    if (command != null && command.trim().isNotEmpty) {
      _append('> $command\n');
    }
    state = state.copyWith(isRunning: true);

    void onEvent(List<int> event) {
      _append(String.fromCharCodes(event));
    }

    process.stdout.listen(onEvent);
    process.stderr.listen(onEvent);
    unawaited(
      process.exitCode.then((_) {
        state = state.copyWith(isRunning: false);
      }),
    );
  }

  /// Appends [chunk] and drops the oldest lines once the buffer exceeds
  /// [maxLogCharacters]. The last line is always kept so the tail of the
  /// output (what the user is watching) stays visible.
  void _append(String chunk) {
    final lines = [...state.lines, chunk];
    _characterCount += chunk.length;
    var dropped = 0;
    while (_characterCount > maxLogCharacters && dropped < lines.length - 1) {
      _characterCount -= lines[dropped].length;
      dropped++;
    }
    state = state.copyWith(
      lines: dropped == 0 ? lines : lines.sublist(dropped),
    );
  }

  // The dialog is opened from a button inside the tree, so it needs the
  // caller's context; there is no build context available on the notifier.
  // ignore: avoid_build_context_in_providers
  void openLogsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: state.lines.isNotEmpty
            ? SingleChildScrollView(child: Text(state.lines.join('\n')))
            : const Text('No logs yet'),
      ),
    );
  }
}

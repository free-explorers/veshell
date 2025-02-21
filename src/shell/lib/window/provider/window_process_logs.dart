import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/model/window_id.dart';

part 'window_process_logs.g.dart';

@riverpod
class WindowProcessLogs extends _$WindowProcessLogs {
  StreamSubscription<List<int>>? _stderrStreamSubscription;
  StreamSubscription<List<int>>? _stdoutStreamSubscription;

  @override
  List<String> build(WindowId windowId) {
    return [];
  }

  void setProcess(Process process) {
    reset();
    void onEvent(List<int> event) {
      final string = String.fromCharCodes(event);
      print('process: $string');
      state = [...state, string];
    }

    _stdoutStreamSubscription = process.stdout.listen(
      onEvent,
    );
    _stderrStreamSubscription = process.stderr.listen(
      onEvent,
    );
  }

  void reset() {
    _stdoutStreamSubscription?.cancel();
    _stderrStreamSubscription?.cancel();
    _stdoutStreamSubscription = null;
    _stderrStreamSubscription = null;
    state = [];
  }
}

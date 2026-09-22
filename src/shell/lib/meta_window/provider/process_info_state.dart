import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/event/process_info/process_info.serializable.dart';

part 'process_info_state.g.dart';

/// Process facts per pid, fed by `process_info` platform events.
///
/// The pid-keyed raw signal table: cgroup and the sandbox/binary identities
/// belong to the process, not to any single window, so they are stored once
/// per pid rather than duplicated on every native window.
@Riverpod(keepAlive: true)
class ProcessInfoState extends _$ProcessInfoState {
  @override
  IMap<int, ProcessInfoMessage> build() => IMap();

  void set(ProcessInfoMessage info) {
    state = state.add(info.pid, info);
  }

  ProcessInfoMessage? forPid(int pid) => state[pid];
}

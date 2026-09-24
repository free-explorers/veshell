import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/model/matching_decision.dart';

part 'matching_decision_recorder.g.dart';

/// Recording-scoped sink for [MatchingDecision]s.
///
/// The matcher publishes its decisions here; `PlatformEventRecorder` starts
/// the sink when a debug launch recording begins and appends every decision to
/// the platform event dump. While no recording is active the sink drops
/// everything, so the ordinary matching path stays signal-free.
///
/// Delivery is synchronous so decisions land in the dump in the same order as
/// the platform events that triggered them.
@Riverpod(keepAlive: true)
class MatchingDecisionRecorder extends _$MatchingDecisionRecorder {
  final List<void Function(MatchingDecision decision)> _listeners = [];
  bool _active = false;

  bool get isActive => _active;

  @override
  void build() {
    ref.onDispose(_listeners.clear);
  }

  void start() => _active = true;

  void stop() => _active = false;

  /// Registers [listener] and returns a callback that removes it again.
  void Function() listen(void Function(MatchingDecision decision) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void record(MatchingDecision decision) {
    if (!_active) return;
    for (final listener in List.of(_listeners)) {
      listener(decision);
    }
  }
}

/// Publishes a matching decision only while a debug recording is active, so a
/// normal run never pays for building the record. [build] is called eagerly
/// only when the sink is listening.
void recordMatchingDecision(Ref ref, MatchingDecision Function() build) {
  final recorder = ref.read(matchingDecisionRecorderProvider.notifier);
  if (recorder.isActive) {
    recorder.record(build());
  }
}

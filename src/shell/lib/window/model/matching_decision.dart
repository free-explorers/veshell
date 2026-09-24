import 'package:shell/window/model/window_id.serializable.dart';

/// A single matching/attribution decision, captured for the debug launch
/// recorder.
///
/// These records are never persisted in the application state: they are built
/// only while a recording is active and appended to the platform event dump as
/// `_matching` records, so a mismatched attribution can be explained after the
/// fact (candidate costs, recovery branches, dispatch moves).
class MatchingDecision {
  const MatchingDecision._(this.kind, this.data);

  /// The routing decision taken by `MetaWindowManager.onMetaWindowMapped` /
  /// `_maybeRerouteAsDialog` before the ordinary matcher runs.
  factory MatchingDecision.routing({
    required String metaWindowId,
    required String appId,
    required int pid,
    required bool isModal,
    required bool isFixedSized,
    required String branch,
    String? parent,
    String? activatedBy,
    String? ownerWindowId,
  }) => MatchingDecision._('routing', {
    'metaWindowId': metaWindowId,
    'appId': appId,
    'pid': pid,
    'parent': parent,
    'activatedBy': activatedBy,
    'isModal': isModal,
    'isFixedSized': isFixedSized,
    'branch': branch,
    'ownerWindowId': ownerWindowId,
  });

  /// The outcome when ordinary matching found no candidate: tracked-launch
  /// provenance, process-sibling recovery, or a brand-new window.
  factory MatchingDecision.fallback({
    required String metaWindowId,
    required String appId,
    required int pid,
    required String outcome,
    String? cgroup,
    String? trackedWindowId,
    String? siblingWindowId,
  }) => MatchingDecision._('fallback', {
    'metaWindowId': metaWindowId,
    'appId': appId,
    'pid': pid,
    'cgroup': cgroup,
    'outcome': outcome,
    'trackedWindowId': trackedWindowId,
    'siblingWindowId': siblingWindowId,
  });

  /// The ordinary candidate ranking: every candidate's cost breakdown and the
  /// chosen one (with whether the fixed tie-break decided it).
  factory MatchingDecision.candidates({
    required String metaWindowId,
    required String appId,
    required int pid,
    required List<String> excludedWindowIds,
    required List<Map<String, Object?>> candidates,
    required bool tieBreak,
    String? chosenWindowId,
    int? chosenCost,
  }) => MatchingDecision._('candidates', {
    'metaWindowId': metaWindowId,
    'appId': appId,
    'pid': pid,
    'excludedWindowIds': excludedWindowIds,
    'candidates': candidates,
    'chosenWindowId': chosenWindowId,
    'chosenCost': chosenCost,
    'tieBreak': tieBreak,
  });

  /// Which owned native window a tile chose to display, with the cost and
  /// fixed-size penalty of each candidate.
  factory MatchingDecision.display({
    required String windowId,
    required List<Map<String, Object?>> owned,
    String? displayedWindowId,
  }) => MatchingDecision._('display', {
    'windowId': windowId,
    'displayedWindowId': displayedWindowId,
    'owned': owned,
  });

  /// A native window moved between tiles during redistribution.
  factory MatchingDecision.move({
    required String windowId,
    required String metaWindowId,
    required String toWindowId,
    required String reason,
    Map<String, Object?>? cost,
  }) => MatchingDecision._('move', {
    'windowId': windowId,
    'metaWindowId': metaWindowId,
    'toWindowId': toWindowId,
    'reason': reason,
    'cost': cost,
  });

  /// A native window turned into a dialog of its tile when no sibling was
  /// available.
  factory MatchingDecision.dialog({
    required String windowId,
    required String metaWindowId,
  }) => MatchingDecision._('dialog', {
    'windowId': windowId,
    'metaWindowId': metaWindowId,
  });

  /// The end of a launch gather (`settled`) or an automatic reopen.
  factory MatchingDecision.burst({
    required String windowId,
    required String phase,
  }) => MatchingDecision._('burst', {'windowId': windowId, 'phase': phase});

  /// A window already matched re-routed as a dialog once a late parent/modal/
  /// activation hint arrived inside its settle window.
  factory MatchingDecision.reroute({
    required String metaWindowId,
    required String fromWindowId,
    required String toWindowId,
    required String reason,
  }) => MatchingDecision._('reroute', {
    'metaWindowId': metaWindowId,
    'fromWindowId': fromWindowId,
    'toWindowId': toWindowId,
    'reason': reason,
  });

  final String kind;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {'kind': kind, ...data};
}

/// Stable, compact string key of a shell window, matching the matcher's own
/// tie-break key style.
String windowIdKey(WindowId windowId) => switch (windowId) {
  DialogWindowId(:final uuid) => 'd:$uuid',
  PersistentWindowId(:final uuid) => 'p:$uuid',
  EphemeralWindowId(:final uuid) => 'e:$uuid',
};

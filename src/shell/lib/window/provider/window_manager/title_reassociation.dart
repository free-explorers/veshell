import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/window_manager/matching_utils.dart';

part 'title_reassociation.g.dart';

/// A settled launch-burst window whose ownership is still provisional.
class PendingTitleReassociation {
  const PendingTitleReassociation({
    required this.burstTiles,
    required this.settledAt,
  });

  /// The tiles that took part in the burst: the origin and every tile it
  /// dispatched a window to. A late title only re-decides ownership among
  /// these, never against unrelated tiles of the same application.
  final ISet<WindowId> burstTiles;

  /// When the burst settled. The re-association window is measured from here.
  final DateTime settledAt;
}

/// Windows dispatched by a launch burst that may still move to a better burst
/// tile once their generic startup title becomes specific.
///
/// A restored session (VS Code) maps every window with the application name
/// and only reports the workspace title once its renderer has restored it, so
/// the burst settle spreads the windows before the discriminator exists. Only
/// windows whose title was still generic at the settle are registered. An
/// entry ends on a successful move, on expiry
/// ([MAX_TITLE_REASSOCIATION_TIME_MS]), on any user input to the window
/// (including input received before the settle), when the window becomes a
/// dialog, or when it goes away. Kept alive on its own: the matching engine is
/// auto-disposed.
@Riverpod(keepAlive: true)
class TitleReassociation extends _$TitleReassociation {
  /// Windows the user clicked, tapped or typed into. Remembered for the
  /// window's lifetime so input during the gather still prevents a later
  /// registration. Not part of the state: it never needs to notify.
  final Set<MetaWindowId> _interacted = {};
  final Set<Timer> _expiryTimers = {};

  @override
  IMap<MetaWindowId, PendingTitleReassociation> build() {
    ref.onDispose(() {
      for (final timer in _expiryTimers) {
        timer.cancel();
      }
      _expiryTimers.clear();
    });
    return IMap();
  }

  /// Registers the windows a burst settled across [burstTiles].
  ///
  /// A burst that ended on a single tile has nowhere to re-associate to and
  /// registers nothing, and a window the user already interacted with is
  /// skipped.
  void registerBurst(
    Iterable<MetaWindowId> metaWindowIds,
    Iterable<WindowId> burstTiles, {
    DateTime? now,
  }) {
    final tiles = burstTiles.toISet();
    if (tiles.length < 2) {
      return;
    }
    final settledAt = now ?? DateTime.now();
    final pending = PendingTitleReassociation(
      burstTiles: tiles,
      settledAt: settledAt,
    );
    var next = _withoutExpired(state, settledAt);
    var added = false;
    for (final metaWindowId in metaWindowIds) {
      if (_interacted.contains(metaWindowId)) {
        continue;
      }
      next = next.add(metaWindowId, pending);
      added = true;
    }
    state = next;
    if (added && now == null) {
      _scheduleExpiry();
    }
  }

  /// The burst tiles [metaWindowId] may still be re-associated among, or
  /// `null` when it is not pending (never registered, consumed, cancelled or
  /// expired).
  ISet<WindowId>? pendingTilesFor(MetaWindowId metaWindowId, {DateTime? now}) {
    final pending = state[metaWindowId];
    if (pending == null) {
      return null;
    }
    if (_isExpired(pending, now ?? DateTime.now())) {
      state = state.remove(metaWindowId);
      return null;
    }
    return pending.burstTiles;
  }

  /// Ends the provisional ownership of [metaWindowId]: it moved, or it became
  /// a dialog.
  void cancel(MetaWindowId metaWindowId) {
    if (state.containsKey(metaWindowId)) {
      state = state.remove(metaWindowId);
    }
  }

  /// The user clicked, tapped or typed into [metaWindowId]: it is never
  /// re-associated, even when its burst has not settled yet.
  void markInteracted(MetaWindowId metaWindowId) {
    _interacted.add(metaWindowId);
    cancel(metaWindowId);
  }

  /// [metaWindowId] went away.
  void forget(MetaWindowId metaWindowId) {
    _interacted.remove(metaWindowId);
    cancel(metaWindowId);
  }

  void _scheduleExpiry() {
    late final Timer timer;
    timer = Timer(
      const Duration(milliseconds: MAX_TITLE_REASSOCIATION_TIME_MS + 1),
      () {
        _expiryTimers.remove(timer);
        if (ref.mounted) {
          state = _withoutExpired(state, DateTime.now());
        }
      },
    );
    _expiryTimers.add(timer);
  }

  static bool _isExpired(PendingTitleReassociation pending, DateTime now) =>
      now.difference(pending.settledAt).inMilliseconds >
      MAX_TITLE_REASSOCIATION_TIME_MS;

  static IMap<MetaWindowId, PendingTitleReassociation> _withoutExpired(
    IMap<MetaWindowId, PendingTitleReassociation> entries,
    DateTime now,
  ) => entries.removeWhere((_, pending) => _isExpired(pending, now));
}

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/mpris/model/mpris_player.dart';

part 'mpris_manager_state.freezed.dart';

/// Every MPRIS player currently on the session bus, plus the user's explicit
/// selection.
///
/// [selectedBusName] is only set when the user picks a player from the
/// switcher. Until then [activePlayer] follows playback: the running player
/// wins.
@freezed
abstract class MprisManagerState with _$MprisManagerState {
  const factory MprisManagerState({
    required IMap<String, MprisPlayer> players,

    /// The player the user explicitly selected, if any.
    String? selectedBusName,
  }) = _MprisManagerState;

  const MprisManagerState._();

  /// The players in a stable order (bus-name insertion order).
  List<MprisPlayer> get playerList => players.values.toList();

  /// The player the control drives:
  /// 1. the explicitly selected one, while it is still present;
  /// 2. otherwise a playing player, so the control reflects what you hear;
  /// 3. otherwise the first known player.
  ///
  /// `null` when no MPRIS player is available.
  MprisPlayer? get activePlayer {
    if (players.isEmpty) {
      return null;
    }
    final selected = selectedBusName;
    if (selected != null) {
      final player = players[selected];
      if (player != null) {
        return player;
      }
    }
    return players.values.firstWhereOrNull((player) => player.isPlaying) ??
        players.values.first;
  }
}

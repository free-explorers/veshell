import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/shared/mpris/model/mpris_manager_state.dart';
import 'package:shell/shared/mpris/model/mpris_playback_status.dart';
import 'package:shell/shared/mpris/model/mpris_player.dart';

void main() {
  MprisManagerState stateWith(List<MprisPlayer> players, {String? selected}) =>
      MprisManagerState(
        players: {for (final player in players) player.busName: player}.lock,
        selectedBusName: selected,
      );

  group('activePlayer', () {
    test('is null without players', () {
      expect(stateWith(const []).activePlayer, isNull);
    });

    test('follows the playing player by default', () {
      const stopped = MprisPlayer(busName: 'a', identity: 'A');
      const playing = MprisPlayer(
        busName: 'b',
        identity: 'B',
        playbackStatus: MprisPlaybackStatus.playing,
      );

      expect(stateWith([stopped, playing]).activePlayer, playing);
    });

    test('falls back to the first player when none plays', () {
      const first = MprisPlayer(busName: 'a');
      const second = MprisPlayer(busName: 'b');

      expect(stateWith([first, second]).activePlayer, first);
    });

    test('prefers an explicit selection over a playing player', () {
      const selected = MprisPlayer(busName: 'a');
      const playing = MprisPlayer(
        busName: 'b',
        playbackStatus: MprisPlaybackStatus.playing,
      );

      expect(
        stateWith([selected, playing], selected: 'a').activePlayer,
        selected,
      );
    });

    test('ignores a stale selection', () {
      const playing = MprisPlayer(
        busName: 'b',
        playbackStatus: MprisPlaybackStatus.playing,
      );

      expect(stateWith([playing], selected: 'gone').activePlayer, playing);
    });
  });

  group('playerList', () {
    test('keeps bus-name insertion order', () {
      const first = MprisPlayer(busName: 'a');
      const second = MprisPlayer(busName: 'b');

      expect(stateWith([first, second]).playerList, [first, second]);
    });
  });
}

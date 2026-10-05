import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/shared/mpris/model/mpris_loop_status.dart';
import 'package:shell/shared/mpris/model/mpris_playback_status.dart';
import 'package:shell/shared/mpris/model/mpris_player.dart';
import 'package:shell/shared/mpris/model/mpris_properties.dart';

void main() {
  group('playerFromProperties', () {
    test('reads the player state, capabilities and track', () {
      final player = playerFromProperties(
        busName: 'org.mpris.MediaPlayer2.spotify',
        playerProperties: {
          'PlaybackStatus': const DBusString('Playing'),
          'LoopStatus': const DBusString('Track'),
          'Shuffle': const DBusBoolean(true),
          'Rate': const DBusDouble(1),
          'Position': const DBusInt64(30000000),
          'CanGoNext': const DBusBoolean(true),
          'CanGoPrevious': const DBusBoolean(true),
          'CanPlay': const DBusBoolean(true),
          'CanPause': const DBusBoolean(true),
          'CanSeek': const DBusBoolean(true),
          'CanControl': const DBusBoolean(true),
          'Metadata': DBusDict.stringVariant({
            'mpris:trackid': DBusObjectPath('/track/1'),
            'mpris:length': const DBusInt64(180000000),
            'mpris:artUrl': const DBusString('file:///tmp/art.png'),
            'xesam:title': const DBusString('Song'),
            'xesam:album': const DBusString('Album'),
            'xesam:artist': DBusArray.string(['Artist', 'Other']),
          }),
        },
        rootProperties: {
          'Identity': const DBusString('Spotify'),
          'CanRaise': const DBusBoolean(true),
        },
        positionUpdatedAt: DateTime.utc(2026),
      );

      expect(player.busName, 'org.mpris.MediaPlayer2.spotify');
      expect(player.identity, 'Spotify');
      expect(player.playbackStatus, MprisPlaybackStatus.playing);
      expect(player.loopStatus, MprisLoopStatus.track);
      expect(player.shuffle, isTrue);
      expect(player.canSeek, isTrue);
      expect(player.canRaise, isTrue);
      expect(player.track.trackId, '/track/1');
      expect(player.track.title, 'Song');
      expect(player.track.artists, ['Artist', 'Other']);
      expect(player.track.album, 'Album');
      expect(player.track.length, const Duration(minutes: 3));
      expect(player.track.artUrl, 'file:///tmp/art.png');
      expect(player.position, const Duration(seconds: 30));
      expect(player.positionUpdatedAt, DateTime.utc(2026));
    });

    test('defaults identity to the bus-name suffix and state to stopped', () {
      final player = playerFromProperties(
        busName: 'org.mpris.MediaPlayer2.spotify',
        playerProperties: const {},
      );

      expect(player.identity, 'spotify');
      expect(player.playbackStatus, MprisPlaybackStatus.stopped);
      expect(player.loopStatus, MprisLoopStatus.none);
      expect(player.track.title, isNull);
    });

    test('tolerates a single string artist and a string track id', () {
      final player = playerFromProperties(
        busName: 'org.mpris.MediaPlayer2.vlc',
        playerProperties: {
          'Metadata': DBusDict.stringVariant({
            'mpris:trackid': const DBusString('/track/2'),
            'xesam:artist': const DBusString('Solo'),
          }),
        },
      );

      expect(player.track.artists, ['Solo']);
      expect(player.track.trackId, '/track/2');
    });

    test('ignores a wrongly typed property instead of throwing', () {
      final player = playerFromProperties(
        busName: 'org.mpris.MediaPlayer2.mpd',
        playerProperties: {
          'PlaybackStatus': const DBusInt64(42),
          'Rate': const DBusString('fast'),
        },
      );

      expect(player.playbackStatus, MprisPlaybackStatus.stopped);
      expect(player.rate, 1);
    });
  });

  group('playerWithChanges', () {
    test('applies partial changes and keeps untouched fields', () {
      const player = MprisPlayer(
        busName: 'org.mpris.MediaPlayer2.spotify',
        rate: 0.5,
        position: Duration(seconds: 10),
      );

      final updated = playerWithChanges(player, {
        'PlaybackStatus': const DBusString('Paused'),
        'Shuffle': const DBusBoolean(true),
        'Position': const DBusInt64(20000000),
      }, positionUpdatedAt: DateTime.utc(2026));

      expect(updated.playbackStatus, MprisPlaybackStatus.paused);
      expect(updated.shuffle, isTrue);
      expect(updated.rate, 0.5);
      expect(updated.position, const Duration(seconds: 20));
      expect(updated.positionUpdatedAt, DateTime.utc(2026));
    });

    test('keeps the position timestamp when position is unchanged', () {
      final sampledAt = DateTime.utc(2026);
      final player = MprisPlayer(
        busName: 'org.mpris.MediaPlayer2.spotify',
        positionUpdatedAt: sampledAt,
      );

      final updated = playerWithChanges(player, {
        'PlaybackStatus': const DBusString('Playing'),
      }, positionUpdatedAt: DateTime.utc(2027));

      expect(updated.positionUpdatedAt, sampledAt);
    });
  });

  group('estimatedPositionAt', () {
    test('interpolates from the last sample while playing', () {
      final player = MprisPlayer(
        busName: 'org.mpris.MediaPlayer2.spotify',
        playbackStatus: MprisPlaybackStatus.playing,
        position: const Duration(seconds: 10),
        positionUpdatedAt: DateTime.utc(2026),
      );

      expect(
        player.estimatedPositionAt(DateTime.utc(2026, 1, 1, 0, 0, 5)),
        const Duration(seconds: 15),
      );
    });

    test('does not advance while paused', () {
      final player = MprisPlayer(
        busName: 'org.mpris.MediaPlayer2.spotify',
        position: const Duration(seconds: 10),
        positionUpdatedAt: DateTime.utc(2026),
      );

      expect(
        player.estimatedPositionAt(DateTime.utc(2027)),
        const Duration(seconds: 10),
      );
    });
  });

  group('icon resolution', () {
    test('playerName strips the bus prefix and instance suffix', () {
      const player = MprisPlayer(
        busName: 'org.mpris.MediaPlayer2.brave.instance36198',
      );

      expect(player.playerName, 'brave');
    });

    test('playerName keeps a dotted player name', () {
      const player = MprisPlayer(
        busName: 'org.mpris.MediaPlayer2.google-play-music-desktop-player',
      );

      expect(player.playerName, 'google-play-music-desktop-player');
    });

    test('iconId prefers the advertised desktop entry', () {
      const player = MprisPlayer(
        busName: 'org.mpris.MediaPlayer2.brave.instance36198',
        desktopEntry: 'brave-browser',
      );

      expect(player.iconId, 'brave-browser');
    });

    test('iconId falls back to the bus name without a desktop entry', () {
      const player = MprisPlayer(
        busName: 'org.mpris.MediaPlayer2.brave.instance36198',
      );

      expect(player.iconId, 'brave');
    });

    test('iconId falls back for an empty desktop entry', () {
      const player = MprisPlayer(
        busName: 'org.mpris.MediaPlayer2.vlc',
        desktopEntry: '',
      );

      expect(player.iconId, 'vlc');
    });
  });

  group('isMprisBusName', () {
    test('matches suffixed player names only', () {
      expect(isMprisBusName('org.mpris.MediaPlayer2.spotify'), isTrue);
      expect(isMprisBusName('org.mpris.MediaPlayer2'), isFalse);
      expect(isMprisBusName('org.freedesktop.Notifications'), isFalse);
    });
  });
}

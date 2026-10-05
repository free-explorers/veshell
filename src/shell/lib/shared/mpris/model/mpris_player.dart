import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/mpris/model/mpris_loop_status.dart';
import 'package:shell/shared/mpris/model/mpris_playback_status.dart';
import 'package:shell/shared/mpris/model/mpris_track.dart';

part 'mpris_player.freezed.dart';

/// The D-Bus name prefix every MPRIS player owns.
const mprisBusNamePrefix = 'org.mpris.MediaPlayer2';

/// A snapshot of one `org.mpris.MediaPlayer2` player.
///
/// It is rebuilt whenever the player's D-Bus properties change, so it carries
/// everything the control needs: identity, transport capabilities, the current
/// track and the last known playback position.
@freezed
abstract class MprisPlayer with _$MprisPlayer {
  const factory MprisPlayer({
    /// The well-known bus name, e.g. `org.mpris.MediaPlayer2.spotify`.
    required String busName,

    /// `org.mpris.MediaPlayer2.Identity`, falling back to the bus-name suffix.
    @Default('') String identity,

    /// `org.mpris.MediaPlayer2.DesktopEntry`, when advertised.
    String? desktopEntry,

    @Default(MprisPlaybackStatus.stopped) MprisPlaybackStatus playbackStatus,

    @Default(MprisLoopStatus.none) MprisLoopStatus loopStatus,

    @Default(false) bool shuffle,

    /// `Rate`, the playback speed multiplier (`1.0` is normal).
    @Default(1) double rate,

    @Default(MprisTrack()) MprisTrack track,

    /// The `Position` reported by the player when it was last sampled.
    @Default(Duration.zero) Duration position,

    /// When [position] was sampled. Used to interpolate the progress bar
    /// between the (deliberately infrequent) position polls. `null` while
    /// unknown.
    DateTime? positionUpdatedAt,

    @Default(false) bool canGoNext,
    @Default(false) bool canGoPrevious,
    @Default(false) bool canPlay,
    @Default(false) bool canPause,
    @Default(false) bool canSeek,

    /// `CanControl`: when false the player only reports state and must not be
    /// driven by the control.
    @Default(false) bool canControl,

    /// `CanRaise`: whether the player's window can be brought forward.
    @Default(false) bool canRaise,
  }) = _MprisPlayer;

  const MprisPlayer._();

  bool get isPlaying => playbackStatus == MprisPlaybackStatus.playing;

  /// The player name encoded in [busName], without the MPRIS prefix or an
  /// `.instanceNNN` suffix: `org.mpris.MediaPlayer2.brave.instance36198` gives
  /// `brave`.
  String get playerName {
    const prefix = '$mprisBusNamePrefix.';
    final name = busName.startsWith(prefix)
        ? busName.substring(prefix.length)
        : busName;
    return name.replaceFirst(RegExp(r'\.instance\d+$'), '');
  }

  /// The desktop-entry id used to resolve this player's icon.
  ///
  /// Prefers the advertised [desktopEntry]; some players do not implement it
  /// (Brave, for one) and fall back to [playerName], which
  /// `LocalizedDesktopEntryForId` can still map to a desktop entry through the
  /// Exec basename or `StartupWMClass`.
  String get iconId {
    final entry = desktopEntry;
    return entry != null && entry.isNotEmpty ? entry : playerName;
  }

  /// The position to display at [now], interpolating from the last sampled
  /// [position] while the player is running.
  Duration estimatedPositionAt(DateTime now) {
    final updatedAt = positionUpdatedAt;
    if (!isPlaying || updatedAt == null) {
      return position;
    }
    final elapsedMicroseconds = now.difference(updatedAt).inMicroseconds * rate;
    return position + Duration(microseconds: elapsedMicroseconds.round());
  }
}

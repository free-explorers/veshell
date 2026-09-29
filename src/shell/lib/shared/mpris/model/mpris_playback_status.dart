/// The `PlaybackStatus` of an MPRIS player.
///
/// The wire values are the strings `Playing`, `Paused` and `Stopped`; anything
/// unrecognized is treated as [stopped].
enum MprisPlaybackStatus {
  playing,
  paused,
  stopped;

  /// Parses the value exposed by the MPRIS `PlaybackStatus` property.
  static MprisPlaybackStatus fromDbusValue(String value) => switch (value) {
    'Playing' => playing,
    'Paused' => paused,
    _ => stopped,
  };
}

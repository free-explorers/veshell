/// The `LoopStatus` of an MPRIS player.
enum MprisLoopStatus {
  none,
  track,
  playlist;

  /// Parses the value exposed by the MPRIS `LoopStatus` property.
  static MprisLoopStatus fromDbusValue(String value) => switch (value) {
    'Track' => track,
    'Playlist' => playlist,
    _ => none,
  };

  /// The value written back to the MPRIS `LoopStatus` property.
  String get dbusValue => switch (this) {
    none => 'None',
    track => 'Track',
    playlist => 'Playlist',
  };

  /// The next status in the cycle used by the control's repeat button:
  /// off → repeat all → repeat one → off.
  MprisLoopStatus get next => switch (this) {
    none => playlist,
    playlist => track,
    track => none,
  };
}

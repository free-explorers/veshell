import 'package:freezed_annotation/freezed_annotation.dart';

part 'mpris_track.freezed.dart';

/// The currently loaded track of an MPRIS player, built from its `Metadata`
/// property.
///
/// Every field is optional because the MPRIS metadata dictionary is sparse in
/// practice: players fill in the keys they care about and leave the rest out.
@freezed
abstract class MprisTrack with _$MprisTrack {
  const factory MprisTrack({
    /// `mpris:trackid` — the D-Bus object path identifying the track.
    String? trackId,

    /// `xesam:title`.
    String? title,

    /// `xesam:artist`.
    @Default(<String>[]) List<String> artists,

    /// `xesam:album`.
    String? album,

    /// `xesam:albumArtist`.
    @Default(<String>[]) List<String> albumArtists,

    /// `mpris:artUrl` — an `http(s)://` or `file://` URL.
    String? artUrl,

    /// `xesam:url` — the track's own URL.
    String? url,

    /// `mpris:length` — the track duration, when advertised.
    Duration? length,
  }) = _MprisTrack;

  const MprisTrack._();

  /// The primary line shown for the track: its title, falling back to its URL.
  String? get displayTitle => title ?? url;

  /// The secondary line: the artists, falling back to the album.
  String get displaySubtitle {
    if (artists.isNotEmpty) {
      return artists.join(', ');
    }
    return album ?? '';
  }
}

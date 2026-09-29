import 'package:dbus/dbus.dart';
import 'package:shell/shared/mpris/model/mpris_loop_status.dart';
import 'package:shell/shared/mpris/model/mpris_playback_status.dart';
import 'package:shell/shared/mpris/model/mpris_player.dart';
import 'package:shell/shared/mpris/model/mpris_track.dart';

/// The root MPRIS interface, carrying player identity.
const mprisRootInterface = 'org.mpris.MediaPlayer2';

/// The player MPRIS interface, carrying playback state and controls.
const mprisPlayerInterface = 'org.mpris.MediaPlayer2.Player';

/// The fixed object path every MPRIS player exposes both interfaces on.
final mprisObjectPath = DBusObjectPath('/org/mpris/MediaPlayer2');

/// The synthetic track id MPRIS uses when no track is loaded.
const mprisNoTrackId = '/org/mpris/MediaPlayer2/TrackList/NoTrack';

/// Whether [name] is an MPRIS player bus name.
bool isMprisBusName(String name) => name.startsWith('$mprisBusNamePrefix.');

/// Builds a player snapshot from the properties of both MPRIS interfaces.
///
/// [playerProperties] is the result of `GetAll` on
/// `org.mpris.MediaPlayer2.Player`; [rootProperties] the one on
/// `org.mpris.MediaPlayer2` and may be empty for minimal players.
/// [positionUpdatedAt] records when `Position` was sampled, if it was.
MprisPlayer playerFromProperties({
  required String busName,
  required Map<String, DBusValue> playerProperties,
  Map<String, DBusValue> rootProperties = const {},
  DateTime? positionUpdatedAt,
}) {
  return MprisPlayer(
    busName: busName,
    identity: _string(rootProperties, 'Identity') ?? _fallbackIdentity(busName),
    desktopEntry: _string(rootProperties, 'DesktopEntry'),
    playbackStatus: MprisPlaybackStatus.fromDbusValue(
      _string(playerProperties, 'PlaybackStatus') ?? 'Stopped',
    ),
    loopStatus: MprisLoopStatus.fromDbusValue(
      _string(playerProperties, 'LoopStatus') ?? 'None',
    ),
    shuffle: _boolean(playerProperties, 'Shuffle'),
    volume: _double(playerProperties, 'Volume') ?? 1,
    rate: _double(playerProperties, 'Rate') ?? 1,
    track: trackFromMetadata(playerProperties['Metadata']),
    position: _duration(playerProperties, 'Position') ?? Duration.zero,
    positionUpdatedAt: positionUpdatedAt,
    canGoNext: _boolean(playerProperties, 'CanGoNext'),
    canGoPrevious: _boolean(playerProperties, 'CanGoPrevious'),
    canPlay: _boolean(playerProperties, 'CanPlay'),
    canPause: _boolean(playerProperties, 'CanPause'),
    canSeek: _boolean(playerProperties, 'CanSeek'),
    canControl: _boolean(playerProperties, 'CanControl'),
    canRaise: _boolean(rootProperties, 'CanRaise'),
  );
}

/// Applies a `PropertiesChanged` payload for the player interface to [player].
///
/// Keys absent from [changed] keep their current value, so a partial update
/// never resets unrelated state.
MprisPlayer playerWithChanges(
  MprisPlayer player,
  Map<String, DBusValue> changed, {
  required DateTime positionUpdatedAt,
}) {
  final positionChanged = changed.containsKey('Position');
  return player.copyWith(
    playbackStatus: _pick(
      changed,
      'PlaybackStatus',
      player.playbackStatus,
      (value) => MprisPlaybackStatus.fromDbusValue(value.asString()),
    ),
    loopStatus: _pick(
      changed,
      'LoopStatus',
      player.loopStatus,
      (value) => MprisLoopStatus.fromDbusValue(value.asString()),
    ),
    shuffle: _pick(changed, 'Shuffle', player.shuffle, (v) => v.asBoolean()),
    volume: _pick(changed, 'Volume', player.volume, (v) => v.asDouble()),
    rate: _pick(changed, 'Rate', player.rate, (v) => v.asDouble()),
    track: changed.containsKey('Metadata')
        ? trackFromMetadata(changed['Metadata'])
        : player.track,
    position: positionChanged
        ? _durationFrom(changed['Position']) ?? player.position
        : player.position,
    positionUpdatedAt: positionChanged
        ? positionUpdatedAt
        : player.positionUpdatedAt,
    canGoNext: _pick(
      changed,
      'CanGoNext',
      player.canGoNext,
      (v) => v.asBoolean(),
    ),
    canGoPrevious: _pick(
      changed,
      'CanGoPrevious',
      player.canGoPrevious,
      (v) => v.asBoolean(),
    ),
    canPlay: _pick(changed, 'CanPlay', player.canPlay, (v) => v.asBoolean()),
    canPause: _pick(changed, 'CanPause', player.canPause, (v) => v.asBoolean()),
    canSeek: _pick(changed, 'CanSeek', player.canSeek, (v) => v.asBoolean()),
    canControl: _pick(
      changed,
      'CanControl',
      player.canControl,
      (v) => v.asBoolean(),
    ),
  );
}

/// Parses the `Metadata` property (`a{sv}`) into a track.
MprisTrack trackFromMetadata(DBusValue? metadata) {
  if (metadata == null) {
    return const MprisTrack();
  }
  final Map<String, DBusValue> values;
  try {
    values = metadata.asStringVariantDict();
  } on Object catch (_) {
    return const MprisTrack();
  }
  return MprisTrack(
    trackId:
        _objectPath(values, 'mpris:trackid') ??
        _string(values, 'mpris:trackid'),
    title: _string(values, 'xesam:title'),
    artists: _stringList(values, 'xesam:artist'),
    album: _string(values, 'xesam:album'),
    albumArtists: _stringList(values, 'xesam:albumArtist'),
    artUrl: _string(values, 'mpris:artUrl'),
    url: _string(values, 'xesam:url'),
    length: _duration(values, 'mpris:length'),
  );
}

/// The identity shown when a player omits `Identity`: the bus-name suffix, so
/// `org.mpris.MediaPlayer2.spotify` reads as `spotify`.
String _fallbackIdentity(String busName) {
  const prefix = '$mprisBusNamePrefix.';
  return busName.startsWith(prefix)
      ? busName.substring(prefix.length)
      : busName;
}

/// Converts [key] with [convert], returning `null` on a missing key or a value
/// whose D-Bus type does not match what the caller expects.
T? _convert<T>(
  Map<String, DBusValue> values,
  String key,
  T Function(DBusValue value) convert,
) {
  final value = values[key];
  if (value == null) {
    return null;
  }
  try {
    return convert(value);
  } on Object catch (_) {
    return null;
  }
}

/// [_convert] with a fallback, used to leave a field untouched on a bad update.
T _pick<T>(
  Map<String, DBusValue> values,
  String key,
  T current,
  T Function(DBusValue value) convert,
) {
  return _convert(values, key, convert) ?? current;
}

String? _string(Map<String, DBusValue> values, String key) =>
    _convert(values, key, (value) => value.asString());

String? _objectPath(Map<String, DBusValue> values, String key) =>
    _convert(values, key, (value) => value.asObjectPath().value);

bool _boolean(Map<String, DBusValue> values, String key) =>
    _convert(values, key, (value) => value.asBoolean()) ?? false;

double? _double(Map<String, DBusValue> values, String key) =>
    _convert(values, key, (value) => value.asDouble());

/// Reads a string array, tolerating players that expose a single string.
List<String> _stringList(Map<String, DBusValue> values, String key) {
  final list = _convert(
    values,
    key,
    (value) => value.asStringArray().where((s) => s.isNotEmpty).toList(),
  );
  if (list != null) {
    return list;
  }
  final single = _string(values, key);
  return single == null || single.isEmpty ? const [] : [single];
}

/// Reads a microsecond count (`x`) as a [Duration].
Duration? _duration(Map<String, DBusValue> values, String key) =>
    _durationFrom(values[key]);

Duration? _durationFrom(DBusValue? value) {
  if (value == null) {
    return null;
  }
  try {
    return Duration(microseconds: value.asInt64());
  } on Object catch (_) {
    return null;
  }
}

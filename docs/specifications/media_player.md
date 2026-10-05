# MediaPlayer

## Description

The overview media control shows what the session is playing and lets the user
drive it, in the spirit of Android's media controls. It speaks
[MPRIS](https://specifications.freedesktop.org/mpris-spec/latest/) (the
`org.mpris.MediaPlayer2` D-Bus interface), the de-facto standard every Linux
player implements (Spotify, Firefox, mpv, VLC, Rhythmbox, …).

The control renders as a Helm card at the top of the control `PanelColumn` in
the [Overview](overview.md). Its header leads with the player's application
icon and identity, falling back to a music glyph and "Media" when the player
cannot be resolved. The card then shows the current title, artist/album and
album art, a seek bar, and the transport controls (previous, play/pause, next),
plus shuffle and repeat. When several players run at once, the header offers a
switcher.

Volume is controlled only through the existing Volume card's PulseAudio
controls. MPRIS player volume is not exposed or tracked: some players (including
Chromium-based browsers) report `Volume` but do not implement writes, making a
separate player slider misleading.

Unlike the notification server, MPRIS is **not** a service Veshell owns: it is a
client of the session bus. It therefore lives entirely in the Dart shell,
alongside the other session-bus clients (Bluetooth, NetworkManager, UPower,
PulseAudio) and needs no Rust or platform-channel work. The connection is the
session bus (`DBusClient.session()`), not the system bus.

## Discovery

A player owns a well-known name under `org.mpris.MediaPlayer2`, e.g.
`org.mpris.MediaPlayer2.spotify` (an instance suffix like `.instance1234` is
allowed). Discovery is name-owner driven:

- `ListNames` seeds the player set at startup;
- `NameOwnerChanged` adds a player when its name is acquired and removes it
  when it is released.

The initial subscription is registered **before** `ListNames`, so a player that
appears in between is either listed or delivered as a signal, never missed.

## State

Every player exposes both interfaces at the fixed path
`/org/mpris/MediaPlayer2`:

| Interface | Properties read |
|---|---|
| `org.mpris.MediaPlayer2` | `Identity`, `DesktopEntry`, `CanRaise` |
| `org.mpris.MediaPlayer2.Player` | `PlaybackStatus`, `LoopStatus`, `Shuffle`, `Rate`, `Metadata`, `Position`, `CanGoNext`, `CanGoPrevious`, `CanPlay`, `CanPause`, `CanSeek`, `CanControl` |

`GetAll` builds the first snapshot; a `PropertiesChanged` signal for the Player
interface applies the changed keys and leaves every other field untouched, so a
partial update never resets unrelated state. An update that only invalidates
properties triggers a full re-read of that player. Unsupported or wrongly typed
properties are ignored rather than treated as fatal, because players differ in
how complete their metadata is.

`Metadata` is decoded into the track: `mpris:trackid`, `xesam:title`,
`xesam:artist`, `xesam:album`, `xesam:albumArtist`, `mpris:artUrl`,
`xesam:url` and `mpris:length`. A player that exposes a single string where the
spec asks for a string array is tolerated.

### Position

MPRIS only signals seeks (`Seeked`); it does not stream the playback position.
`Position` is therefore polled once a second **while a player is running**, and
the snapshot records when it was sampled. The control interpolates from that
sample (scaled by `Rate`) every 500 ms, so the bar advances smoothly without a
D-Bus round trip per frame. The poll timer only exists while something plays and
is torn down when playback stops.

## Controls

All controls act on the player returned by `activePlayer`:

1. the player the user explicitly selected, while it is still present;
2. otherwise a playing player, so the control reflects what you hear;
3. otherwise the first known player.

`playerList` keeps bus-name insertion order for the switcher. Removing the
selected player clears the selection, falling back to rule 2.

| Action | MPRIS call |
|---|---|
| Play/pause | `PlayPause` |
| Next / previous | `Next` / `Previous` |
| Stop | `Stop` |
| Seek | `SetPosition(trackId, position)`, or relative `Seek(offset)` when the track id is unknown or `NoTrack` |
| Shuffle | `Shuffle` property |
| Repeat | `LoopStatus` property, cycled off → repeat all → repeat one |
| Bring to front | `Raise` on the root interface |

Shuffle, loop and seek update the snapshot optimistically so the UI
responds immediately; the write is best-effort and a failure is only logged.
Transport buttons are disabled when the player cannot perform the action
(`CanControl`, `CanGoNext`, `CanGoPrevious`, `CanPlay`, `CanPause`), and the
seek bar is read-only unless `CanSeek`.

## UI

`mediaPlayerSection` returns `null` when no player is present, so the card
never appears empty. Album art resolves `file://` and `http(s)://` URLs, with a
neutral music glyph as fallback for missing or broken art. The card is a plain
`Card` (not an `ExpandableCard`), so its controls stay directly reachable in the
overview.

## Keyboard media keys

The hardware media keys are bound to the active player through the shell hotkey
system (see `shortcut_manager`), with defaults in
`extra/settings/default/settings.json`:

| Action id | Default | Player call |
|---|---|---|
| `media.playPause` | `mediaPlayPause` | `PlayPause` |
| `media.next` | `mediaTrackNext` | `Next` |
| `media.previous` | `mediaTrackPrevious` | `Previous` |
| `media.stop` | `mediaStop` | `Stop` |

They are regular configurable hotkeys, so a user can rebind them like any other.

The play/pause button is not reported consistently: some compositors emit
`XF86AudioPlayPause` (Flutter `mediaPlayPause`), others `XF86AudioPlay` or
`XF86AudioPause` (`mediaPlay`/`mediaPause`). When `media.playPause` is bound to
any of those three keys, the shell accepts the whole family so the physical
button keeps working whichever name the compositor reports.

Because the compositor forwards every key to Flutter before the focused client
(and does not forward a shortcut Flutter handled), the media keys are global:
they drive the player even while an application window has keyboard focus.

## Out of scope (future milestone)

`org.mpris.MediaPlayer2.TrackList` and `.Playlists`, `OpenUri`, `Quit`, desktop
entry icons (the control shows a generic media glyph rather than the
application icon), and per-player history.

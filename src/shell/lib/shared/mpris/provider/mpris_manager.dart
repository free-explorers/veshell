import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/mpris/model/mpris_manager_state.dart';
import 'package:shell/shared/mpris/model/mpris_player.dart';
import 'package:shell/shared/mpris/model/mpris_properties.dart';
import 'package:shell/shared/mpris/provider/mpris_dbus_client.dart';
import 'package:shell/shared/util/logger.dart';

part 'mpris_manager.g.dart';

/// Discovers `org.mpris.MediaPlayer2` players on the session bus and tracks
/// their state, so the overview control can show what is playing and drive it.
///
/// Discovery is bus-name driven: every player owns a name under
/// [mprisBusNamePrefix], so `ListNames` seeds the set and `NameOwnerChanged`
/// keeps it in sync. Per-player state comes from `PropertiesChanged`, with a
/// periodic `Position` poll while a player is running (MPRIS does not signal
/// the progress continuously).
@Riverpod(keepAlive: true)
class MprisManager extends _$MprisManager {
  /// Live snapshots, kept outside the provider state so property events that
  /// arrive while the async [build] is still resolving are not lost.
  final _players = <String, MprisPlayer>{};
  final _objects = <String, DBusRemoteObject>{};
  final _subscriptions =
      <String, StreamSubscription<DBusPropertiesChangedSignal>>{};

  /// The player explicitly chosen by the user, if any.
  String? _selectedBusName;

  Timer? _positionTimer;
  var _refreshingPositions = false;

  /// Whether [build] has returned, so [_emit] can safely assign [state].
  var _built = false;

  late DBusClient _client;

  @override
  Future<MprisManagerState> build() async {
    _built = false;
    _client = ref.watch(mprisDbusClientProvider);
    ref.onDispose(_dispose);

    // Subscribe before the initial listing: a name that appears in between is
    // either in `ListNames` or delivered as a `NameOwnerChanged`, never both
    // missed.
    final nameSubscription = _client.nameOwnerChanged.listen(
      _onNameOwnerChanged,
    );
    ref.onDispose(nameSubscription.cancel);

    try {
      final names = await _client.listNames();
      for (final name in names.where(isMprisBusName)) {
        await _addPlayer(name);
      }
    } on Object catch (error) {
      mprisLog.warning('Unable to list MPRIS players', error);
    }

    _updatePositionTimer();
    _built = true;
    return _snapshot();
  }

  /// The player the control currently drives, or `null` when none is available.
  MprisPlayer? get activePlayer => state.value?.activePlayer;

  /// Makes [busName] the active player until it disappears.
  void selectPlayer(String busName) {
    if (!_players.containsKey(busName)) {
      return;
    }
    _selectedBusName = busName;
    _emit();
  }

  /// Toggles play/pause on the active player.
  void playPause() => unawaited(_callPlayer('PlayPause'));

  /// Skips to the next track on the active player.
  void next() => unawaited(_callPlayer('Next'));

  /// Skips to the previous track on the active player.
  void previous() => unawaited(_callPlayer('Previous'));

  /// Stops the active player.
  void stop() => unawaited(_callPlayer('Stop'));

  /// Brings the active player's window forward (`Raise`).
  void raise() =>
      unawaited(_callPlayer('Raise', interface: mprisRootInterface));

  /// Seeks the active player to [target].
  ///
  /// The progress bar is moved optimistically so a drag lands immediately;
  /// `SetPosition` is used when the track id is known, `Seek` otherwise.
  void seekTo(Duration target) {
    final player = activePlayer;
    if (player == null || !player.canSeek) {
      return;
    }
    final object = _objects[player.busName];
    if (object == null) {
      return;
    }
    _updatePlayer(
      player.copyWith(position: target, positionUpdatedAt: DateTime.now()),
    );
    unawaited(_seek(object, player, target));
  }

  Future<void> _seek(
    DBusRemoteObject object,
    MprisPlayer player,
    Duration target,
  ) async {
    try {
      final trackId = player.track.trackId;
      if (trackId != null && trackId.isNotEmpty && trackId != mprisNoTrackId) {
        await object.callMethod(mprisPlayerInterface, 'SetPosition', [
          DBusObjectPath(trackId),
          DBusInt64(target.inMicroseconds),
        ]);
      } else {
        // `Seek` is relative to the player's real position, which the
        // optimistic update did not change.
        final offset = target - player.position;
        await object.callMethod(mprisPlayerInterface, 'Seek', [
          DBusInt64(offset.inMicroseconds),
        ]);
      }
    } on Object catch (error) {
      mprisLog.warning('MPRIS seek failed for ${player.busName}', error);
    }
  }

  /// Cycles the active player's shuffle state.
  void toggleShuffle() {
    final player = activePlayer;
    if (player == null) {
      return;
    }
    final shuffle = !player.shuffle;
    _updatePlayer(player.copyWith(shuffle: shuffle));
    unawaited(
      _setPlayerProperty(player.busName, 'Shuffle', DBusBoolean(shuffle)),
    );
  }

  /// Cycles the active player's loop status: off → repeat all → repeat one.
  void cycleLoopStatus() {
    final player = activePlayer;
    if (player == null) {
      return;
    }
    final loopStatus = player.loopStatus.next;
    _updatePlayer(player.copyWith(loopStatus: loopStatus));
    unawaited(
      _setPlayerProperty(
        player.busName,
        'LoopStatus',
        DBusString(loopStatus.dbusValue),
      ),
    );
  }

  void _onNameOwnerChanged(DBusNameOwnerChangedEvent event) {
    if (!isMprisBusName(event.name)) {
      return;
    }
    if (event.newOwner != null) {
      unawaited(_addPlayer(event.name));
    } else {
      _removePlayer(event.name);
    }
  }

  Future<void> _addPlayer(String busName) async {
    if (_players.containsKey(busName)) {
      return;
    }
    final object = DBusRemoteObject(
      _client,
      name: busName,
      path: mprisObjectPath,
    );
    try {
      final player = await _fetchPlayer(object, busName);
      // The name may have been released while the properties were in flight.
      if (_players.containsKey(busName)) {
        return;
      }
      _objects[busName] = object;
      _players[busName] = player;
      _subscriptions[busName] = object.propertiesChanged.listen(
        (signal) => _onPropertiesChanged(busName, signal),
      );
      _emit();
      _updatePositionTimer();
    } on Object catch (error) {
      mprisLog.warning('Unable to read MPRIS player $busName', error);
    }
  }

  Future<MprisPlayer> _fetchPlayer(
    DBusRemoteObject object,
    String busName,
  ) async {
    final playerProperties = await object.getAllProperties(
      mprisPlayerInterface,
    );
    var rootProperties = const <String, DBusValue>{};
    try {
      rootProperties = await object.getAllProperties(mprisRootInterface);
    } on Object catch (_) {
      // The root interface is optional for minimal players; identity falls
      // back to the bus-name suffix.
    }
    return playerFromProperties(
      busName: busName,
      playerProperties: playerProperties,
      rootProperties: rootProperties,
      positionUpdatedAt: playerProperties.containsKey('Position')
          ? DateTime.now()
          : null,
    );
  }

  void _onPropertiesChanged(
    String busName,
    DBusPropertiesChangedSignal signal,
  ) {
    if (signal.propertiesInterface != mprisPlayerInterface) {
      return;
    }
    final player = _players[busName];
    if (player == null) {
      return;
    }
    _players[busName] = playerWithChanges(
      player,
      signal.changedProperties,
      positionUpdatedAt: DateTime.now(),
    );
    _emit();
    _updatePositionTimer();

    // An invalidated property cannot be read from the signal: re-read the whole
    // player to converge.
    if (signal.invalidatedProperties.isNotEmpty) {
      unawaited(_refreshPlayer(busName));
    }
  }

  Future<void> _refreshPlayer(String busName) async {
    final object = _objects[busName];
    if (object == null) {
      return;
    }
    try {
      final player = await _fetchPlayer(object, busName);
      if (_objects[busName] != object) {
        return;
      }
      _players[busName] = player;
      _emit();
      _updatePositionTimer();
    } on Object catch (error) {
      mprisLog.warning('Unable to refresh MPRIS player $busName', error);
    }
  }

  void _removePlayer(String busName) {
    if (_players.remove(busName) == null) {
      return;
    }
    unawaited(_subscriptions.remove(busName)?.cancel());
    _objects.remove(busName);
    if (_selectedBusName == busName) {
      _selectedBusName = null;
    }
    _emit();
    _updatePositionTimer();
  }

  /// Samples `Position` for every running player once a second.
  ///
  /// MPRIS only signals seeks, so this is what keeps the progress bar moving;
  /// the control interpolates between samples. The timer only exists while
  /// something is playing.
  Future<void> _refreshPositions() async {
    if (_refreshingPositions) {
      return;
    }
    _refreshingPositions = true;
    try {
      for (final busName in _players.keys.toList()) {
        final object = _objects[busName];
        if (object == null) {
          continue;
        }
        try {
          final value = await object.getProperty(
            mprisPlayerInterface,
            'Position',
          );
          final current = _players[busName];
          if (current == null || !current.isPlaying) {
            continue;
          }
          _players[busName] = current.copyWith(
            position: Duration(microseconds: value.asInt64()),
            positionUpdatedAt: DateTime.now(),
          );
        } on Object catch (_) {
          // The player may be going away; NameOwnerChanged removes it.
        }
      }
      _emit();
    } finally {
      _refreshingPositions = false;
    }
  }

  void _updatePositionTimer() {
    final anyPlaying = _players.values.any((player) => player.isPlaying);
    if (!anyPlaying) {
      _positionTimer?.cancel();
      _positionTimer = null;
      return;
    }
    _positionTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refreshPositions()),
    );
  }

  Future<void> _callPlayer(
    String method, {
    String interface = mprisPlayerInterface,
  }) async {
    final player = activePlayer;
    if (player == null) {
      return;
    }
    final object = _objects[player.busName];
    if (object == null) {
      return;
    }
    try {
      await object.callMethod(interface, method, const []);
    } on Object catch (error) {
      mprisLog.warning('MPRIS $method failed for ${player.busName}', error);
    }
  }

  Future<void> _setPlayerProperty(
    String busName,
    String name,
    DBusValue value,
  ) async {
    final object = _objects[busName];
    if (object == null) {
      return;
    }
    try {
      await object.setProperty(mprisPlayerInterface, name, value);
    } on Object catch (error) {
      mprisLog.warning('MPRIS $name update failed for $busName', error);
    }
  }

  void _updatePlayer(MprisPlayer player) {
    _players[player.busName] = player;
    _emit();
  }

  MprisManagerState _snapshot() => MprisManagerState(
    players: _players.lock,
    selectedBusName: _players.containsKey(_selectedBusName)
        ? _selectedBusName
        : null,
  );

  void _emit() {
    if (!_built) {
      return;
    }
    state = AsyncData(_snapshot());
  }

  void _dispose() {
    _positionTimer?.cancel();
    _positionTimer = null;
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _objects.clear();
    _players.clear();
    _selectedBusName = null;
  }
}

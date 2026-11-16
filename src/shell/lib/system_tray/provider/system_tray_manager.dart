import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/painting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/system_tray/model/system_tray_activation_token/system_tray_activation_token.serializable.dart';
import 'package:shell/system_tray/model/system_tray_item_registered/system_tray_item_registered.serializable.dart';
import 'package:shell/system_tray/model/system_tray_request.dart';
import 'package:shell/system_tray/model/tray_item.dart';
import 'package:shell/system_tray/model/tray_menu.dart';
import 'package:shell/system_tray/model/tray_properties.dart';

part 'system_tray_manager.g.dart';

/// The session-bus connection tray items live on.
@Riverpod(keepAlive: true)
DBusClient systemTrayDbusClient(Ref ref) {
  final client = DBusClient.session();
  ref.onDispose(client.close);
  return client;
}

/// The shell's StatusNotifierHost: the tray items the compositor's watcher
/// registered, in registration order, each read from its application.
///
/// The compositor owns `org.kde.StatusNotifierWatcher` and forwards every
/// registration with the item's address; this manager reads the item's
/// properties, follows its change signals and drives it (activation, scroll,
/// menu). See `docs/specifications/system_tray.md`.
@Riverpod(keepAlive: true)
class SystemTrayManager extends _$SystemTrayManager {
  /// Live snapshots, kept outside the provider state so the ones read while
  /// [build] is running are not lost.
  final _items = <String, TrayItem>{};
  final _objects = <String, DBusRemoteObject>{};
  final _subscriptions = <String, StreamSubscription<DBusSignal>>{};
  final _refreshTimers = <String, Timer>{};

  late DBusClient _client;
  var _built = false;

  @override
  IList<TrayItem> build() {
    _built = false;
    _client = ref.watch(systemTrayDbusClientProvider);
    ref.onDispose(_dispose);
    final subscription = ref
        .watch(platformManagerProvider)
        .listen(_onPlatformEvent);
    ref.onDispose(subscription.cancel);
    // Now that the subscription exists, the compositor may deliver the items
    // registered so far.
    unawaited(
      ref
          .read(platformManagerProvider.notifier)
          .request(const SystemTrayReadyRequest()),
    );
    _built = true;
    return _snapshot();
  }

  void _onPlatformEvent(PlatformEvent event) {
    switch (event) {
      case SystemTrayItemRegisteredEvent(:final message):
        unawaited(_addItem(message));
      case SystemTrayItemUnregisteredEvent(:final message):
        _removeItem(message.id);
      default:
        break;
    }
  }

  Future<void> _addItem(SystemTrayItemRegisteredMessage message) async {
    final id = message.id;
    if (_objects.containsKey(id)) return;
    final object = DBusRemoteObject(
      _client,
      name: message.busName,
      path: DBusObjectPath(message.objectPath),
    );
    _objects[id] = object;
    _items[id] = TrayItem(
      id: id,
      busName: message.busName,
      objectPath: message.objectPath,
      pid: message.pid,
    );
    // Every `New*` signal means "re-read me"; `NewStatus` also carries the
    // status, applied at once.
    _subscriptions[id] =
        DBusSignalStream(
          _client,
          sender: message.busName,
          interface: trayItemInterface,
          path: DBusObjectPath(message.objectPath),
        ).listen(
          (signal) => _onItemSignal(id, signal),
          onError: (Object error) =>
              systemTrayLog.fine('Tray item $id signal error', error),
        );
    // An item is only shown once its properties are known.
    await _refreshItem(id, retry: true);
  }

  void _onItemSignal(String id, DBusSignal signal) {
    final item = _items[id];
    if (item == null) return;
    if (signal.name == 'NewStatus' &&
        signal.values.isNotEmpty &&
        signal.values.first is DBusString) {
      _items[id] = item.copyWith(
        status: TrayItemStatus.fromDbusValue(signal.values.first.asString()),
      );
      _emit();
      return;
    }
    // Applications often send several signals in a row (icon, tooltip,
    // title): read the item once for all of them.
    _refreshTimers[id]?.cancel();
    _refreshTimers[id] = Timer(
      const Duration(milliseconds: 50),
      () => unawaited(_refreshItem(id)),
    );
  }

  Future<void> _refreshItem(String id, {bool retry = false}) async {
    final object = _objects[id];
    if (object == null) return;
    try {
      final properties = await object.getAllProperties(trayItemInterface);
      final item = _items[id];
      if (item == null || _objects[id] != object) return;
      _items[id] = trayItemWithProperties(item, properties);
      _known.add(id);
      _emit();
    } on Object catch (error) {
      if (retry) {
        // Some applications register their item a moment before they export
        // it: try once more before giving up.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return await _refreshItem(id);
      }
      systemTrayLog.warning('Unable to read tray item $id', error);
    }
  }

  /// The ids whose properties were read at least once: only those are shown.
  final _known = <String>{};

  void _removeItem(String id) {
    _objects.remove(id);
    _items.remove(id);
    _known.remove(id);
    _refreshTimers.remove(id)?.cancel();
    unawaited(_subscriptions.remove(id)?.cancel());
    _emit();
  }

  /// Activates [id] as a primary click at [position] (global, logical
  /// pixels) does. Returns `false` when the item does not implement
  /// `Activate`, in which case the caller opens its menu instead.
  ///
  /// The item first gets a trusted activation token, so the window it shows
  /// is focused and brought into view.
  Future<bool> activate(String id, Offset position) async {
    final object = _objects[id];
    if (object == null) return false;
    await _provideActivationToken(id, object);
    return await _call(object, 'Activate', _position(position));
  }

  /// `SecondaryActivate`, the middle click.
  Future<void> secondaryActivate(String id, Offset position) async {
    final object = _objects[id];
    if (object == null) return;
    await _provideActivationToken(id, object);
    await _call(object, 'SecondaryActivate', _position(position));
  }

  /// `ContextMenu`, for an item that shows its menu itself instead of
  /// exporting a `com.canonical.dbusmenu`.
  Future<void> contextMenu(String id, Offset position) async {
    final object = _objects[id];
    if (object == null) return;
    await _call(object, 'ContextMenu', _position(position));
  }

  /// `Scroll` by [delta] steps along [orientation] (`vertical` or
  /// `horizontal`).
  Future<void> scroll(String id, int delta, String orientation) async {
    final object = _objects[id];
    if (object == null) return;
    await _call(object, 'Scroll', [DBusInt32(delta), DBusString(orientation)]);
  }

  /// Sends `clicked` for the menu entry [entryId] of [id]'s menu.
  ///
  /// An entry such as "Open" shows the application's window just as
  /// `Activate` does, so the item gets the same trusted activation first.
  Future<void> menuEntryClicked(
    String id,
    TrayMenuClient client,
    int entryId,
  ) async {
    final object = _objects[id];
    if (object != null) await _provideActivationToken(id, object);
    await client.event(entryId, 'clicked');
  }

  /// The item's menu, or `null` when it has none.
  TrayMenuClient? menuClient(String id) {
    final item = _items[id];
    final menuPath = item?.menuPath;
    if (item == null || menuPath == null) return null;
    return TrayMenuClient(
      DBusRemoteObject(
        _client,
        name: item.busName,
        path: DBusObjectPath(menuPath),
      ),
    );
  }

  /// Hands the item a trusted activation token before it is activated
  /// (`ProvideXdgActivationToken`, a later addition to the specification).
  /// Best effort: applications that predate it answer an error.
  Future<void> _provideActivationToken(
    String id,
    DBusRemoteObject object,
  ) async {
    try {
      final token = await ref
          .read(platformManagerProvider.notifier)
          .requestResult(
            SystemTrayActivationTokenRequest(
              message: SystemTrayActivationTokenMessage(id: id),
            ),
          );
      if (token is! String) return;
      await object.callMethod(trayItemInterface, 'ProvideXdgActivationToken', [
        DBusString(token),
      ], replySignature: DBusSignature.empty);
    } on Object catch (_) {
      // Not implemented by this application.
    }
  }

  Future<bool> _call(
    DBusRemoteObject object,
    String method,
    List<DBusValue> values,
  ) async {
    try {
      await object.callMethod(trayItemInterface, method, values);
      return true;
    } on Object catch (error) {
      systemTrayLog.fine('Tray item ${object.name} $method failed', error);
      return false;
    }
  }

  static List<DBusValue> _position(Offset position) => [
    DBusInt32(position.dx.round()),
    DBusInt32(position.dy.round()),
  ];

  IList<TrayItem> _snapshot() => [
    for (final entry in _items.entries)
      if (_known.contains(entry.key)) entry.value,
  ].lock;

  void _emit() {
    if (!_built) return;
    state = _snapshot();
  }

  void _dispose() {
    for (final timer in _refreshTimers.values) {
      timer.cancel();
    }
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    _refreshTimers.clear();
    _subscriptions.clear();
    _objects.clear();
    _items.clear();
    _known.clear();
  }
}

/// A client of one tray item's `com.canonical.dbusmenu`.
class TrayMenuClient {
  TrayMenuClient(this.object);

  final DBusRemoteObject object;

  /// The menu's root entry and its descendants, or `null` when it could not
  /// be read.
  Future<TrayMenuEntry?> layout() async {
    try {
      final response = await object.callMethod(trayMenuInterface, 'GetLayout', [
        const DBusInt32(0),
        const DBusInt32(-1),
        DBusArray.string(trayMenuProperties),
      ], replySignature: DBusSignature('u(ia{sv}av)'));
      return trayMenuEntryFrom(response.values[1]);
    } on Object catch (error) {
      systemTrayLog.warning('Unable to read tray menu ${object.name}', error);
      return null;
    }
  }

  /// `AboutToShow`: lets the application populate [id] before it opens.
  /// Returns whether the layout must be read again.
  Future<bool> aboutToShow(int id) async {
    try {
      final response = await object.callMethod(
        trayMenuInterface,
        'AboutToShow',
        [DBusInt32(id)],
        replySignature: DBusSignature('b'),
      );
      return response.values.first.asBoolean();
    } on Object catch (_) {
      return false;
    }
  }

  /// Sends the `clicked`, `opened` or `closed` event for [id].
  Future<void> event(int id, String eventId) async {
    try {
      await object.callMethod(trayMenuInterface, 'Event', [
        DBusInt32(id),
        DBusString(eventId),
        const DBusVariant(DBusInt32(0)),
        DBusUint32(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ], replySignature: DBusSignature.empty);
    } on Object catch (error) {
      systemTrayLog.fine('Tray menu $eventId failed for $id', error);
    }
  }

  /// The menu's change signals: the layout must be read again.
  Stream<DBusSignal> get changes =>
      DBusSignalStream(
        object.client,
        sender: object.name,
        interface: trayMenuInterface,
        path: object.path,
      ).where(
        (signal) =>
            signal.name == 'LayoutUpdated' ||
            signal.name == 'ItemsPropertiesUpdated',
      );
}

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/provider/dbus_client.dart';
import 'package:ubuntu_session/ubuntu_session.dart';

part 'session.g.dart';

enum SessionControlAction { lock, logout, sleep, hibernate, reboot, shutdown }

@riverpod
Future<Set<SessionControlAction>> sessionControlAvailability(Ref ref) =>
    ref.watch(sessionProvider.notifier).availableControls();

@Riverpod(keepAlive: true)
class Session extends _$Session {
  @override
  SystemdSessionManager build() {
    final client = ref.watch(dbusClientProvider);

    return SystemdSessionManager(bus: client);
  }

  /// Returns a list of all user sessions.
  Future<List<SystemdSession>> getUserSessions() async =>
      Stream.fromIterable(await state.listSessions())
          .asyncMap((session) async {
            final classStr = await session.classString;
            return classStr == 'user' ? session : null;
          })
          .where((session) => session != null)
          .cast<SystemdSession>()
          .toList();

  /// Returns the active user session.
  Future<SystemdSession?> getActiveUserSession() async {
    final sessions = await getUserSessions();
    for (final session in sessions) {
      if (await session.active) {
        return session;
      }
    }
    return null;
  }

  Future<void> shutdown() => state.powerOff(true);

  Future<void> reboot() => state.reboot(true);

  Future<void> sleep() => state.suspend(true);

  Future<Set<SessionControlAction>> availableControls() async {
    final capabilities = await Future.wait([
      _isActionAvailable(state.canSuspend),
      _isActionAvailable(state.canHibernate),
      _isActionAvailable(state.canReboot),
      _isActionAvailable(state.canPowerOff),
    ]);
    final actions = <SessionControlAction>{};
    if (capabilities[0]) actions.add(SessionControlAction.sleep);
    if (capabilities[1]) actions.add(SessionControlAction.hibernate);
    if (capabilities[2]) actions.add(SessionControlAction.reboot);
    if (capabilities[3]) actions.add(SessionControlAction.shutdown);

    try {
      if (await getActiveUserSession() != null) {
        actions.addAll([
          SessionControlAction.lock,
          SessionControlAction.logout,
        ]);
      }
    } catch (_) {
      // Hide session-specific actions if the active session cannot be queried.
    }

    return actions;
  }

  Future<bool> _isActionAvailable(
    Future<String> Function() capabilityQuery,
  ) async {
    try {
      final capability = await capabilityQuery();
      return capability == 'yes' || capability == 'challenge';
    } catch (_) {
      return false;
    }
  }

  Future<void> hibernate() async {
    final capability = await state.canHibernate();
    if (capability != 'yes' && capability != 'challenge') {
      throw StateError(
        'Hibernation is unavailable on this system (logind: $capability).',
      );
    }
    await state.hibernate(true);
  }

  Future<void> logout() async {
    final session = await getActiveUserSession();
    if (session != null) {
      await session.terminate(interactive: true);
    }
  }

  Future<void> lock() async {
    final session = await getActiveUserSession();
    if (session != null) {
      await session.lock(interactive: true);
    }
  }
}

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/provider/dbus_client.dart';
import 'package:ubuntu_session/ubuntu_session.dart';

part 'session.g.dart';

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

  Future<void> sleep() => state.reboot(true);

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

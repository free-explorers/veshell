import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ubuntu_session/ubuntu_session.dart';

part 'session.g.dart';

@riverpod
class Session extends _$Session {
  @override
  SystemdSessionManager build() {
    return SystemdSessionManager();
  }

  Future<SystemdSession?> get activeSession async {
    final sessions = await state.listSessions();

    SystemdSession? activeSession;
    var i = 0;
    while (activeSession == null && i < sessions.length) {
      if (await sessions.elementAt(i).active) {
        activeSession = sessions.elementAt(i);
      }
      i++;
    }
    return activeSession;
  }

  Future<void> shutdown() => state.powerOff(true);

  Future<void> reboot() => state.reboot(true);

  Future<void> sleep() => state.reboot(true);

  Future<void> logout() async {
    final session = await activeSession;
    if (session != null) {
      await session.terminate();
    }
  }

  Future<void> lock() async {
    final session = await activeSession;
    if (session != null) {
      await session.lock();
    }
  }
}

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/polkit/model/authentication_agent.dart';
import 'package:shell/polkit/model/org.freedesktop.PolicyKit1.AuthenticationAgent.dart';
import 'package:shell/shared/provider/dbus_client.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/systemd/provider/session.dart';

part 'authentication_agent.g.dart';

Duration? noRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true, retry: noRetry)
class PolkitAuthenticationAgentState extends _$PolkitAuthenticationAgentState {
  @override
  Future<OrgFreedesktopPolicyKit1AuthenticationAgent> build() async {
    try {
      final client = ref.watch(dbusClientProvider);
      final sessionManager = ref.watch(sessionProvider);
      final agent = PolkitAuthenticationAgent(client, sessionManager, ref);
      await client.registerObject(agent);
      final session = await ref
          .watch(sessionProvider.notifier)
          .getActiveUserSession();
      if (session == null) {
        throw StateError(
          'No active user session found for Polkit registration',
        );
      }
      final sessionId = await session.id;
      await agent.registerAgent(sessionId);
      return agent;
    } catch (error, stackTrace) {
      polkitLog.severe('initialization failed', error, stackTrace);
      rethrow;
    }
  }
}

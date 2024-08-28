import 'package:dbus/dbus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/polkit/model/authentication_agent.dart';
import 'package:shell/polkit/model/org.freedesktop.PolicyKit1.AuthenticationAgent.dart';
import 'package:shell/shared/provider/dbus_client.dart';
import 'package:shell/systemd/provider/session.dart';

part 'authentication_agent.g.dart';

const busName = 'org.freedesktop.PolicyKit1.AuthenticationAgent';
const objectPath = '/org/freedesktop/PolicyKit1/AuthenticationAgent';

@Riverpod(keepAlive: true)
class PolkitAuthenticationAgentState extends _$PolkitAuthenticationAgentState {
  late PolkitAuthenticationAgent _agent;
  late DBusRemoteObject _authority;

  @override
  Future<OrgFreedesktopPolicyKit1AuthenticationAgent> build() async {
    try {
      final client = ref.watch(dbusClientProvider);
      final sessionManager = ref.watch(sessionProvider);
      _agent = PolkitAuthenticationAgent(client, sessionManager);
      await client.registerObject(_agent);
      _authority = DBusRemoteObject(
        client,
        name: 'org.freedesktop.PolicyKit1',
        path: DBusObjectPath('/org/freedesktop/PolicyKit1/Authority'),
      );
      final session =
          await ref.watch(sessionProvider.notifier).getActiveUserSession();
      await _agent.registerAgent(await session!.id);
      return _agent;
    } catch (e) {
      print(e);
      rethrow;
    }
  }
}

import 'package:collection/collection.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/provider/focused_monitor.dart';
import 'package:shell/monitor/provider/navigator_key_for_view.dart';
import 'package:shell/polkit/model/org.freedesktop.PolicyKit1.AuthenticationAgent.dart';
import 'package:shell/polkit/model/polkit-agent-helper.dart';
import 'package:shell/polkit/widget/polkit_authentication_dialog.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:ubuntu_session/ubuntu_session.dart';

const polkitAuthenticationAgentPath =
    '/org/veshell/PolicyKit1/AuthenticationAgent';

class PolkitAuthenticationAgent
    extends OrgFreedesktopPolicyKit1AuthenticationAgent {
  PolkitAuthenticationAgent(DBusClient client, this.manager, this.ref)
    : _authority = DBusRemoteObject(
        client,
        name: 'org.freedesktop.PolicyKit1',
        path: DBusObjectPath('/org/freedesktop/PolicyKit1/Authority'),
      ),
      super(path: DBusObjectPath(polkitAuthenticationAgentPath));
  final DBusRemoteObject _authority;
  final SystemdSessionManager manager;
  final Ref ref;

  /// The navigator context of the focused monitor, where a trusted dialog
  /// must be pushed. Null until a monitor view (and its navigator) exists.
  BuildContext? _focusedNavigatorContext() {
    final monitor = ref.read(focusedMonitorProvider);
    if (monitor == null) {
      return null;
    }
    return ref
        .read(navigatorKeyForViewProvider(monitor.viewId))
        .currentState
        ?.overlay
        ?.context;
  }

  /// Implementation of org.freedesktop.PolicyKit1.AuthenticationAgent.BeginAuthentication()
  @override
  Future<DBusMethodResponse> doBeginAuthentication(
    String actionId,
    String message,
    String iconName,
    Map<String, String> details,
    String cookie,
    List<List<DBusValue>> identities,
  ) async {
    final selectedUser = await selectUserFromIdentities(identities);
    if (selectedUser == null) {
      return DBusMethodErrorResponse.failed('No user selected');
    }

    final helper = await PolkitAgentHelper.start(selectedUser.$2, cookie);
    try {
      while (true) {
        final event = await helper.nextEvent();

        switch (event) {
          case Event.request:
            // Show the prompt on the focused monitor's navigator. There is
            // no app-wide root navigator: each monitor owns one MaterialApp.
            final context = _focusedNavigatorContext();
            if (context == null || !context.mounted) {
              polkitLog.warning(
                'No focused monitor navigator for Polkit prompt',
              );
            }
            final password = context == null || !context.mounted
                ? null
                : await showDialog<String?>(
                    context: context,
                    builder: (context) => PolkitAuthenticationDialog(message),
                  );

            // Send response to Polkit agent helper
            await helper.respond(password ?? '');

          case Event.showError:
            polkitLog.warning('helper reported an authentication error');
          case Event.showDebug:
            break;

          case Event.complete:
            // Authentication complete, dismiss dialog
            return DBusMethodSuccessResponse();
          case Event.failed:
            // Authentication failed, dismiss dialog
            return DBusMethodErrorResponse.failed('Failed');
        }
      }
    } finally {
      await helper.close();
    }
  }

  /// Implementation of org.freedesktop.PolicyKit1.AuthenticationAgent.CancelAuthentication()
  @override
  Future<DBusMethodResponse> doCancelAuthentication(String cookie) async {
    return DBusMethodErrorResponse.failed(
      'org.freedesktop.PolicyKit1.AuthenticationAgent.CancelAuthentication() not implemented',
    );
  }

  Future<void> registerAgent(String sessionId) async {
    await _authority.callMethod(
      'org.freedesktop.PolicyKit1.Authority',
      'RegisterAuthenticationAgent',
      [
        DBusStruct([
          const DBusString('unix-session'),
          DBusDict.stringVariant({'session-id': DBusString(sessionId)}),
        ]),
        const DBusString('en_US.UTF-8'),
        const DBusString(polkitAuthenticationAgentPath),
      ],
    );
  }

  Future<(int, String)?> selectUserFromIdentities(
    List<List<DBusValue>> identities,
  ) async {
    final uids = <int>[];
    for (final ident in identities) {
      final kind = ident.elementAt(0).asString();
      final details = ident.elementAt(1).asStringVariantDict();
      // `unix-user` is apparently a thing, but Gnome Shell doesn't seem to handle it...
      if (kind == 'unix-user') {
        final uid = details.containsKey('uid')
            ? details['uid']!.asUint32()
            : null;
        if (uid != null) {
          uids.add(uid);
        }
      }
      // `unix-group` is apparently a thing too, but Gnome Shell doesn't seem to handle it...
    }

    final userList = await manager.listUsers();
    final activeUser = await getActiveUser(userList);
    final activeUid = await activeUser?.uid;

    var uid = uids.firstWhereOrNull((uid) => uid == activeUid);
    uid ??= uids.firstWhereOrNull((uid) => uid == 0);
    if (uid == null && uids.isNotEmpty) {
      uid = uids.first;
    }
    if (uid == null) {
      return null;
    }
    final user = await getUserByUid(userList, uid);
    if (user == null) {
      return null;
    }
    return (uid, await user.name);
  }

  Future<SystemdUser?> getActiveUser(Iterable<SystemdUser> userList) async {
    for (final user in userList) {
      if (await user.state == 'active') {
        return user;
      }
    }
    return null;
  }

  Future<SystemdUser?> getUserByUid(
    Iterable<SystemdUser> userList,
    int uid,
  ) async {
    for (final user in userList) {
      if (await user.uid == uid) {
        return user;
      }
    }
    return null;
  }
}

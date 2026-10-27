import 'package:flutter_test/flutter_test.dart';
import 'package:shell/lock_screen/model/lock_auth_respond/lock_auth_respond.serializable.dart';
import 'package:shell/lock_screen/model/lock_auth_update/lock_auth_update.serializable.dart';
import 'package:shell/lock_screen/model/lock_screen_state/lock_screen_state.dart';
import 'package:shell/lock_screen/provider/lock_screen.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';

LockAuthUpdateMessage _update(
  LockAuthSource source,
  LockAuthKind kind, [
  String message = '',
]) => LockAuthUpdateMessage(
  source: source,
  kind: kind,
  message: message,
  echo: false,
);

void main() {
  group('platform contract', () {
    test('lock_state_changed decodes the compositor payload', () {
      final event = PlatformEvent.fromJson({
        'method': 'lock_state_changed',
        'message': {'locked': true, 'userName': 'ada', 'realName': 'Ada'},
      });
      expect(event, isA<LockStateChangedEvent>());
      final message = (event as LockStateChangedEvent).message;
      expect(message.locked, isTrue);
      expect(message.realName, 'Ada');
    });

    test('lock_auth_update decodes the compositor payload', () {
      final event = PlatformEvent.fromJson({
        'method': 'lock_auth_update',
        'message': {
          'source': 'fingerprint',
          'kind': 'info',
          'message': 'Place your finger on the reader',
          'echo': false,
        },
      });
      final message = (event as LockAuthUpdateEvent).message;
      expect(message.source, LockAuthSource.fingerprint);
      expect(message.kind, LockAuthKind.info);
    });

    test('the password never shows in toString', () {
      final message = LockAuthRespondMessage(response: 'hunter2');
      expect(message.toString(), isNot(contains('hunter2')));
      expect(message.toJson(), {'response': 'hunter2'});
    });
  });

  group('reduceAuthUpdate', () {
    const locked = LockScreenState(locked: true, userName: 'ada');

    test('a prompt makes the field ready', () {
      final state = reduceAuthUpdate(
        locked.copyWith(checking: true),
        _update(LockAuthSource.password, LockAuthKind.prompt, 'Password: '),
      );
      expect(state.prompt, 'Password: ');
      expect(state.checking, isFalse);
    });

    test('a rejected password counts a failure with the generic text', () {
      final state = reduceAuthUpdate(
        locked.copyWith(checking: true),
        _update(LockAuthSource.password, LockAuthKind.failed),
      );
      expect(state.failureCount, 1);
      expect(state.checking, isFalse);
      expect(state.passwordNotice, const LockScreenNotice(isError: true));
    });

    test('a PAM error explaining the failure is kept', () {
      var state = reduceAuthUpdate(
        locked,
        _update(LockAuthSource.password, LockAuthKind.error, 'Account locked'),
      );
      state = reduceAuthUpdate(
        state,
        _update(LockAuthSource.password, LockAuthKind.failed),
      );
      expect(state.passwordNotice?.text, 'Account locked');
    });

    test('fingerprint messages stay apart from the password field', () {
      var state = reduceAuthUpdate(
        locked,
        _update(LockAuthSource.fingerprint, LockAuthKind.info, 'Touch'),
      );
      expect(state.fingerprintNotice?.text, 'Touch');
      expect(state.passwordNotice, isNull);
      state = reduceAuthUpdate(
        state,
        _update(LockAuthSource.fingerprint, LockAuthKind.unavailable),
      );
      expect(state.fingerprintNotice, isNull);
    });
  });
}

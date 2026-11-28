import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/event/night_light_changed/night_light_changed.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/set_night_light/set_night_light.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'night_light_state.g.dart';

/// Night Light's state, mirrored from the compositor; null until it reports
/// it.
@Riverpod(keepAlive: true)
class NightLightState extends _$NightLightState {
  @override
  NightLightChangedMessage? build() {
    final subscription = ref.watch(platformManagerProvider).listen((event) {
      if (event case NightLightChangedEvent(:final message)) {
        state = message;
      }
    });
    ref.onDispose(subscription.cancel);
    return null;
  }

  /// The Helm toggle: overrides the schedule until its next transition. The
  /// switch moves at once; the compositor's report confirms it.
  void setEnabled({required bool enabled}) {
    final current = state;
    if (current != null) {
      state = current.copyWith(active: enabled);
    }
    unawaited(
      ref
          .read(platformManagerProvider.notifier)
          .request(
            SetNightLightRequest(
              message: SetNightLightMessage(enabled: enabled),
            ),
          ),
    );
  }
}

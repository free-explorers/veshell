import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/capture/model/screen_cast_active/screen_cast_active.serializable.dart';
import 'package:shell/capture/model/screen_cast_stopped/screen_cast_stopped.serializable.dart';
import 'package:shell/capture/model/screen_cast_stop/screen_cast_stop.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screen_cast_indicator.g.dart';

/// Model for [ScreenCastStopRequest]
class ScreenCastStopRequest extends PlatformRequest {
  /// constructor
  const ScreenCastStopRequest({
    required ScreenCastStopMessage super.message,
    super.method = 'screen_cast_stop',
  });
}

/// Live screen cast sessions tracked by the persistent indicator.
@riverpod
class ScreenCastIndicator extends _$ScreenCastIndicator {
  @override
  Map<String, ScreenCastActiveMessage> build() {
    ref.watch(platformManagerProvider).listen((next) {
      if (next case final ScreenCastActiveEvent event) {
        final next_value = {
          ...state,
          event.message.sessionHandle: event.message,
        };
        state = next_value;
      }
      if (next case final ScreenCastStoppedEvent event) {
        final next_value = {...state}..remove(event.message.sessionHandle);
        state = next_value;
      }
    });

    return const {};
  }

  /// User Stop through the trusted indicator: a trusted shell action.
  Future<void> stop(String sessionHandle) async {
    await ref
        .read(platformManagerProvider.notifier)
        .request(
          ScreenCastStopRequest(
            message: ScreenCastStopMessage(sessionHandle: sessionHandle),
          ),
        );
  }
}

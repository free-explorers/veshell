import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/capture/model/screen_cast_active/screen_cast_active.serializable.dart';
import 'package:shell/capture/model/screen_cast_stop/screen_cast_stop.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/util/logger.dart';

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
///
/// Kept alive for the whole shell: the indicator must track casts that
/// start while its view is not the one rebuilding, and a disposed
/// provider would drop the start/stop events that follow.
@Riverpod(keepAlive: true)
class ScreenCastIndicator extends _$ScreenCastIndicator {
  @override
  Map<String, ScreenCastActiveMessage> build() {
    final subscription = ref.watch(platformManagerProvider).listen((next) {
      if (next case final ScreenCastActiveEvent event) {
        captureLog.info(
          'Screen cast active: app="${event.message.appId}" '
          'source="${event.message.sourceLabel}"',
        );
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
    ref.onDispose(subscription.cancel);

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

/// Where each live screen cast landed, keyed by session handle.
///
/// `null` marks an orphan cast: the compositor found no MetaWindow to carry the
/// indicator, so the persistent bar stays as the fallback.
@Riverpod(keepAlive: true)
class ScreenCastRecordingTargets extends _$ScreenCastRecordingTargets {
  @override
  Map<String, String?> build() {
    final subscription = ref.watch(platformManagerProvider).listen((next) {
      if (next case final ScreenCastRecordingEvent event) {
        state = {
          ...state,
          event.message.sessionHandle: event.message.metaWindowId,
        };
      }
      if (next case final ScreenCastStoppedEvent event) {
        state = {...state}..remove(event.message.sessionHandle);
      }
    });
    ref.onDispose(subscription.cancel);

    return const {};
  }
}

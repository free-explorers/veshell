import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/event/brightness_changed/brightness_changed.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/set_brightness/set_brightness.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'display_brightness.g.dart';

/// The display backlight level, in `0.0..1.0`, mirrored from the compositor;
/// null until it reports one, or when it drives no backlight.
@Riverpod(keepAlive: true)
class DisplayBrightness extends _$DisplayBrightness {
  @override
  double? build() {
    final subscription = ref.watch(platformManagerProvider).listen((event) {
      // The slider's own changes are already shown: their echoes can arrive
      // behind a drag and would pull the handle back.
      if (event case BrightnessChangedEvent(
        :final message,
      ) when message.source != BrightnessChangeSource.helm) {
        state = brightnessFromMessage(message);
      }
    });
    ref.onDispose(subscription.cancel);
    return null;
  }

  /// Moves the backlight to [fraction] (the Helm slider). The level shows at
  /// once.
  void set(double fraction) {
    state = fraction.clamp(0.0, 1.0);
    unawaited(
      ref
          .read(platformManagerProvider.notifier)
          .request(
            SetBrightnessRequest(
              message: SetBrightnessMessage(fraction: fraction),
            ),
          ),
    );
  }
}

/// The level a [BrightnessChangedMessage] reports, or null when there is no
/// backlight to control.
double? brightnessFromMessage(BrightnessChangedMessage message) =>
    message.available ? message.fraction.clamp(0.0, 1.0) : null;

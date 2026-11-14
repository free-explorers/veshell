import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/event/keyboard_layout_changed/keyboard_layout_changed.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'active_keyboard_layout.g.dart';

/// The seat's active keyboard layout, mirrored from the compositor; null
/// until it first reports it.
@Riverpod(keepAlive: true)
class ActiveKeyboardLayout extends _$ActiveKeyboardLayout {
  @override
  KeyboardLayoutChangedMessage? build() {
    final subscription = ref.watch(platformManagerProvider).listen((event) {
      if (event case KeyboardLayoutChangedEvent(:final message)) {
        state = message;
      }
    });
    ref.onDispose(subscription.cancel);
    return null;
  }
}

/// The short label of the configured keyboard layout [entry]: its xkb layout
/// name without the variant, upper-cased (`us(altgr-intl)` gives `US`).
String keyboardLayoutLabel(String entry) {
  final variantStart = entry.indexOf('(');
  final layout = variantStart < 0 ? entry : entry.substring(0, variantStart);
  return layout.trim().toUpperCase();
}

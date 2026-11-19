import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_manager.dart';

part 'pointer_screen.g.dart';

/// The screen the pointer last entered, or `null` before it entered any.
///
/// The keyboard follows a click, not the pointer ([focusedScreenProvider]).
/// What surfaces without being asked for (a new window, an unresolved
/// notification, a system prompt) goes where the user is looking instead,
/// which [placementScreenProvider] derives from this, and the shell's Super
/// hotkeys act on this screen (see `VeshellShortcutManager`).
@Riverpod(keepAlive: true)
class PointerScreen extends _$PointerScreen {
  @override
  ScreenId? build() => null;

  /// Records that the pointer entered [screenId].
  void set(ScreenId screenId) {
    if (state == screenId) {
      return;
    }
    state = screenId;
  }
}

/// The screen where something that surfaces on its own should appear: the
/// screen under the pointer, or the focused screen until the pointer entered
/// one (or when the screen it entered no longer exists).
@Riverpod(keepAlive: true)
ScreenId? placementScreen(Ref ref) {
  final pointerScreen = ref.watch(pointerScreenProvider);
  if (pointerScreen != null &&
      ref
          .watch(screenManagerProvider.select((value) => value.screenIds))
          .contains(pointerScreen)) {
    return pointerScreen;
  }
  return ref.watch(focusedScreenProvider);
}

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/shared/util/logger.dart';

/// Finger travel that turns a four-finger swipe into an overview open/close.
///
/// The gesture is normalized like the three-finger rows: a full vertical page
/// is 300 units, so half of it (~3.8 mm of finger movement) commits.
const _overviewSwipeThreshold = 150.0;

/// Opens the overview with a four-finger swipe up and closes it with a swipe
/// down, on the focused screen.
///
/// The three-finger swipes stay with the workspace and tile rows; libinput
/// reports the finger count, so the two gestures never compete.
class OverviewSwipeGesture extends HookConsumerWidget {
  const OverviewSwipeGesture({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(platformManagerProvider);
    final active = useRef(false);
    final naturalScroll = useRef(false);
    // Physical vertical finger travel, negative upwards.
    final travel = useRef<double>(0);

    useEffect(() {
      final subscription = stream.listen((event) {
        if (event is GestureSwipeBeginEvent) {
          active.value = event.message.fingers == 4;
          naturalScroll.value = event.message.naturalScroll;
          travel.value = 0;
          return;
        }
        if (event is GestureSwipeUpdateEvent) {
          if (!active.value || event.message.fingers != 4) {
            return;
          }
          // The compositor negates the deltas under natural scrolling; the
          // overview follows the fingers whatever that setting is.
          travel.value += naturalScroll.value
              ? -event.message.deltaY
              : event.message.deltaY;
          return;
        }
        if (event is GestureSwipeEndEvent) {
          if (!active.value) {
            return;
          }
          active.value = false;
          if (event.message.cancelled) {
            return;
          }
          if (travel.value.abs() < _overviewSwipeThreshold) {
            return;
          }
          final screenId = ref.read(focusedScreenProvider);
          if (screenId == null) {
            return;
          }
          final overview = ref.read(overviewStateProvider(screenId));
          final up = travel.value < 0;
          final shouldToggle = up
              ? !overview.isDisplayed
              : overview.isDisplayed;
          if (!shouldToggle) {
            return;
          }
          gestureLog.info(
            '4-finger swipe ${up ? 'up' : 'down'}: '
            '${overview.isDisplayed ? 'closing' : 'opening'} the overview',
          );
          ref.read(overviewStateProvider(screenId).notifier).toggle();
        }
      });
      return subscription.cancel;
    }, [stream, ref]);

    return child;
  }
}

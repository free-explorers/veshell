import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

typedef _SwipeCallbacks = (
  void Function(GestureSwipeBeginEvent event),
  void Function(GestureSwipeUpdateEvent event),
  void Function(GestureSwipeEndEvent event),
);

class SwipeGestureDetector extends HookConsumerWidget {
  const SwipeGestureDetector({
    required this.child,
    this.onSwipeBegin,
    this.onSwipeUpdate,
    this.onSwipeEnd,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final void Function(GestureSwipeBeginEvent event)? onSwipeBegin;
  final void Function(GestureSwipeUpdateEvent event)? onSwipeUpdate;
  final void Function(GestureSwipeEndEvent event)? onSwipeEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(platformManagerProvider);
    // The callbacks close over the container's state and are recreated on
    // every build. Keep the latest ones in a ref so the subscription below
    // only changes with `enabled`: rebuilding on each swipe update used to
    // tear down and recreate the listener every frame.
    final callbacks = useRef<_SwipeCallbacks?>(null)
      ..value = (
        onSwipeBegin ?? (GestureSwipeBeginEvent event) {},
        onSwipeUpdate ?? (GestureSwipeUpdateEvent event) {},
        onSwipeEnd ?? (GestureSwipeEndEvent event) {},
      );

    useEffect(() {
      if (!enabled) {
        return null;
      }

      final subscription = stream.listen((event) {
        final (begin, update, end) = callbacks.value!;
        if (event is GestureSwipeBeginEvent) {
          begin(event);
        } else if (event is GestureSwipeUpdateEvent) {
          update(event);
        } else if (event is GestureSwipeEndEvent) {
          end(event);
        }
      });
      return subscription.cancel;
    }, [enabled, stream]);
    return child;
  }
}

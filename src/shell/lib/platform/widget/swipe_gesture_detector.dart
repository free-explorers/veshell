import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

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
    final onSwipeBeginCallback = useCallback(
      onSwipeBegin ?? (GestureSwipeBeginEvent event) {},
      [onSwipeBegin],
    );
    final onSwipeUpdateCallback = useCallback(
      onSwipeUpdate ?? (GestureSwipeUpdateEvent event) {},
      [onSwipeUpdate],
    );
    final onSwipeEndCallback = useCallback(
      onSwipeEnd ?? (GestureSwipeEndEvent event) {},
      [onSwipeEnd],
    );

    useEffect(
      () {
        if (!enabled) {
          return () {};
        }

        final subscription = stream.listen((event) {
          if (event is GestureSwipeBeginEvent) {
            onSwipeBeginCallback(event);
          } else if (event is GestureSwipeUpdateEvent) {
            onSwipeUpdateCallback(event);
          } else if (event is GestureSwipeEndEvent) {
            onSwipeEndCallback(event);
          }
        });
        return subscription.cancel;
      },
      [enabled, onSwipeBegin, onSwipeUpdate, onSwipeEnd, stream],
    );
    return child;
  }
}

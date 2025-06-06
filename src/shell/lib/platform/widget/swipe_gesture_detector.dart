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
  final void Function(GestureSwipeBeginEvent)? onSwipeBegin;
  final void Function(GestureSwipeUpdateEvent)? onSwipeUpdate;
  final void Function(GestureSwipeEndEvent)? onSwipeEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(platformManagerProvider);
    useEffect(() {
      final subscription = stream.listen((event) {
        if (!enabled) {
          return;
        }
        if (event is GestureSwipeBeginEvent) {
          onSwipeBegin?.call(event);
        } else if (event is GestureSwipeUpdateEvent) {
          onSwipeUpdate?.call(event);
        } else if (event is GestureSwipeEndEvent) {
          onSwipeEnd?.call(event);
        }
      });
      return subscription.cancel;
    });
    return child;
  }
}

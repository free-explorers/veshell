import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

/// Reports the laid-out size of [child], read through a key after the frame
/// it was laid out in: on every build, and whenever the child is resized
/// without this widget being rebuilt.
class SizeReporter extends HookWidget {
  const SizeReporter({
    required this.onSizeChanged,
    required this.child,
    super.key,
  });

  /// Called with the size of [child]; it may repeat an unchanged size.
  final ValueChanged<Size> onSizeChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final childKey = useMemoized(GlobalKey.new);
    void report() => WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = childKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) onSizeChanged(box.size);
    });

    report();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        report();
        return true;
      },
      child: SizeChangedLayoutNotifier(key: childKey, child: child),
    );
  }
}

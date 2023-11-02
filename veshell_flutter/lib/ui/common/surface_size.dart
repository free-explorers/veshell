import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/common/state/surface_state.dart';

class SurfaceSize extends ConsumerWidget {
  final int viewId;
  final Widget child;

  const SurfaceSize({
    super.key,
    required this.viewId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Size surfaceSize = ref.watch(surfaceStatesProvider(viewId).select((v) => v.surfaceSize));

    return SizedBox(
      width: surfaceSize.width,
      height: surfaceSize.height,
      child: child,
    );
  }
}

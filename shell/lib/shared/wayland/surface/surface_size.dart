import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:veshell/shared/wayland/surface/surface.provider.dart';

class SurfaceSize extends ConsumerWidget {
  const SurfaceSize({
    required this.viewId,
    required this.child,
    super.key,
  });
  final int viewId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceSize =
        ref.watch(surfaceStatesProvider(viewId).select((v) => v.surfaceSize));

    return SizedBox(
      width: surfaceSize.width,
      height: surfaceSize.height,
      child: child,
    );
  }
}

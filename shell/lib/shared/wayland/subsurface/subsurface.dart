import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/wayland/subsurface/subsurface.provider.dart';
import 'package:shell/shared/wayland/surface/surface.provider.dart';

class SubsurfaceWidget extends StatelessWidget {
  const SubsurfaceWidget({
    required this.viewId,
    super.key,
  });
  final int viewId;

  @override
  Widget build(BuildContext context) {
    return _Positioner(
      viewId: viewId,
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          return ref.watch(surfaceWidgetProvider(viewId));
        },
      ),
    );
  }
}

class _Positioner extends ConsumerWidget {
  const _Positioner({
    required this.viewId,
    required this.child,
  });
  final int viewId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position =
        ref.watch(subsurfaceStatesProvider(viewId).select((v) => v.position));

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: child,
    );
  }
}

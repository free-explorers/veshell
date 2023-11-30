import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/wayland/subsurface/subsurface.provider.dart';
import 'package:shell/shared/wayland/surface/surface.provider.dart';

class SubsurfaceWidget extends StatelessWidget {
  const SubsurfaceWidget({
    required this.surfaceId,
    super.key,
  });
  final int surfaceId;

  @override
  Widget build(BuildContext context) {
    return _Positioner(
      surfaceId: surfaceId,
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          return ref.watch(surfaceWidgetProvider(surfaceId));
        },
      ),
    );
  }
}

class _Positioner extends ConsumerWidget {
  const _Positioner({
    required this.surfaceId,
    required this.child,
  });
  final int surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref
        .watch(subsurfaceStatesProvider(surfaceId).select((v) => v.position));

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: child,
    );
  }
}

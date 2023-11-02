import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/common/state/subsurface_state.dart';
import 'package:zenith/ui/common/state/surface_state.dart';

class Subsurface extends StatelessWidget {
  final int viewId;

  const Subsurface({
    super.key,
    required this.viewId,
  });

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
  final int viewId;
  final Widget child;

  const _Positioner({
    Key? key,
    required this.viewId,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Offset position = ref.watch(subsurfaceStatesProvider(viewId).select((v) => v.position));

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: child,
    );
  }
}

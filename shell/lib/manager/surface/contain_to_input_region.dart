import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/manager/surface/surface/surface.provider.dart';
import 'package:shell/shared/util/rect_overflow_box.dart';

class ContainToInputRegion extends ConsumerWidget {
  const ContainToInputRegion({
    required this.surfaceId,
    required this.child,
    super.key,
  });
  final int surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputRegion = ref
        .watch(surfaceStatesProvider(surfaceId).select((v) => v.inputRegion));

    return CropOverflowBox(
      rect: inputRegion,
      child: child,
    );
  }
}

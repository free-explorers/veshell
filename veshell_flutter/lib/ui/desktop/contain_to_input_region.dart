import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/common/state/surface_state.dart';
import 'package:zenith/util/rect_overflow_box.dart';

class ContainToInputRegion extends ConsumerWidget {
  final int viewId;
  final Widget child;

  const ContainToInputRegion({
    super.key,
    required this.viewId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Rect inputRegion = ref.watch(surfaceStatesProvider(viewId).select((v) => v.inputRegion));

    return CropOverflowBox(
      rect: inputRegion,
      child: child,
    );
  }
}

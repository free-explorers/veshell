import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:veshell/shared/util/rect_overflow_box.dart';
import 'package:veshell/shared/wayland/surface/surface.provider.dart';

class ContainToInputRegion extends ConsumerWidget {
  const ContainToInputRegion({
    required this.viewId,
    required this.child,
    super.key,
  });
  final int viewId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputRegion =
        ref.watch(surfaceStatesProvider(viewId).select((v) => v.inputRegion));

    return CropOverflowBox(
      rect: inputRegion,
      child: child,
    );
  }
}

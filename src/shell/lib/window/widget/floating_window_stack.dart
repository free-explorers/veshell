import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/shared/widget/container_with_positionnable_children/container_with_positionnable_children.dart';
import 'package:shell/window/widget/floatable_window.dart';

/// The shared stack scaffolding for floating windows.
///
/// The dialog overlay and the floating tile differ in placement and in the
/// per-window origin/raise callbacks, but both are the same stack of decorated
/// [FloatableWindow] siblings.
class FloatingWindowStack extends StatelessWidget {
  const FloatingWindowStack({
    required this.metaWindowIds,
    this.placement = FloatableWindowPlacement.dialogOverlay,
    this.maxSizeFactor = 1,
    this.frame = false,
    this.tileGlobalOrigin,
    this.clientOriginFor,
    this.onRaise,
    super.key,
  });

  final List<MetaWindowId> metaWindowIds;
  final FloatableWindowPlacement placement;
  final double maxSizeFactor;
  final bool frame;
  final Offset? tileGlobalOrigin;
  final Offset? Function(MetaWindowId metaWindowId)? clientOriginFor;
  final ValueChanged<MetaWindowId>? onRaise;

  @override
  Widget build(BuildContext context) {
    if (metaWindowIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return ContainerWithPositionnableChildren(
      children: [
        for (final metaWindowId in metaWindowIds)
          FloatableWindow(
            key: ValueKey(metaWindowId),
            metaWindowId: metaWindowId,
            placement: placement,
            maxSizeFactor: maxSizeFactor,
            frame: frame,
            tileGlobalOrigin: tileGlobalOrigin,
            clientOrigin: clientOriginFor?.call(metaWindowId),
            onRaise: onRaise == null ? null : () => onRaise!(metaWindowId),
          ),
      ],
    );
  }
}

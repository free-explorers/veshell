import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/desktop/activate_and_raise.dart';
import 'package:zenith/ui/desktop/contain_to_visible_bounds.dart';
import 'package:zenith/ui/desktop/decorations/title_bar.dart';
import 'package:zenith/ui/desktop/with_resize_handles.dart';

class ServerSideDecorations extends StatelessWidget {
  static const double borderWidth = 10;

  final int viewId;
  final Widget child;
  final double cornerWidth;

  const ServerSideDecorations({
    super.key,
    required this.viewId,
    required this.child,
    this.cornerWidth = 30,
  });

  @override
  Widget build(BuildContext context) {
    return ActivateAndRaise(
      viewId: viewId,
      child: WithResizeHandles(
        viewId: viewId,
        borderWidth: borderWidth,
        cornerWidth: cornerWidth,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TitleBar(
                  viewId: viewId,
                ),
                UnconstrainedBox(
                  child: ClipRect(
                    child: ContainToVisibleBounds(
                      viewId: viewId,
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

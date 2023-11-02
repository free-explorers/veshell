import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/platform_api.dart';
import 'package:zenith/ui/common/app_icon.dart';
import 'package:zenith/ui/common/state/xdg_toplevel_state.dart';
import 'package:zenith/ui/desktop/state/window_move_provider.dart';
import 'package:zenith/ui/desktop/state/window_position_provider.dart';

class TitleBar extends ConsumerStatefulWidget {
  final int viewId;

  const TitleBar({super.key, required this.viewId});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _TitleBarState();
  }
}

class _TitleBarState extends ConsumerState<TitleBar> {
  var startPosition = Offset.zero;
  var delta = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (DragDownDetails details) {
        Offset startPosition = ref.read(windowPositionProvider(widget.viewId));
        ref.read(windowMoveProvider(widget.viewId).notifier).startMove(startPosition);
      },
      onPanUpdate: (DragUpdateDetails details) {
        ref.read(windowMoveProvider(widget.viewId).notifier).move(details.delta);
      },
      onPanEnd: (_) {
        ref.read(windowMoveProvider(widget.viewId).notifier).endMove();
      },
      onPanCancel: () {
        ref.read(windowMoveProvider(widget.viewId).notifier).cancelMove();
      },
      child: SizedBox(
        height: 30,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 3.0,
            sigmaY: 3.0,
          ),
          child: Material(
            color: Colors.grey.shade200.withOpacity(0.5),
            child: Stack(
              children: [
                _WindowTitle(viewId: widget.viewId),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _WindowButtons(viewId: widget.viewId),
                    _AppIcon(viewId: widget.viewId),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowTitle extends ConsumerWidget {
  final int viewId;

  const _WindowTitle({
    required this.viewId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String title = ref.watch(xdgToplevelStatesProvider(viewId).select((v) => v.title));

    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _WindowButtons extends ConsumerWidget {
  final int viewId;

  const _WindowButtons({
    required this.viewId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          icon: const Icon(Icons.close),
          iconSize: 18,
          onPressed: () => ref.read(platformApiProvider.notifier).closeView(viewId),
        ),
        _WindowButton(
          icon: const RotatedBox(
            quarterTurns: -1,
            child: Icon(Icons.arrow_forward_ios),
          ),
          iconSize: 15,
          onPressed: () {},
        ),
        _WindowButton(
          icon: const RotatedBox(
            quarterTurns: 1,
            child: Icon(Icons.arrow_forward_ios),
          ),
          iconSize: 15,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _WindowButton extends StatelessWidget {
  final Widget icon;
  final double iconSize;
  final VoidCallback? onPressed;

  const _WindowButton({
    required this.icon,
    required this.iconSize,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        padding: EdgeInsets.zero,
        splashRadius: 22,
        iconSize: iconSize,
        icon: icon,
        onPressed: onPressed,
      ),
    );
  }
}

class _AppIcon extends ConsumerWidget {
  final int viewId;

  const _AppIcon({
    required this.viewId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String appId = ref.watch(xdgToplevelStatesProvider(viewId).select((v) => v.appId));

    return SizedBox(
      height: 30,
      width: 30,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: AppIconById(id: appId),
      ),
    );
  }
}

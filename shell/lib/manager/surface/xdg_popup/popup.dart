import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/manager/surface/surface/surface.provider.dart';
import 'package:shell/manager/surface/xdg_popup/xdg_popup.provider.dart';
import 'package:shell/manager/surface/xdg_surface/xdg_surface.provider.dart';

class Popup extends StatelessWidget {
  const Popup({
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
          final key = ref.watch(
            xdgPopupStatesProvider(surfaceId).select((v) => v.animationsKey),
          );
          return _Animations(
            key: key,
            surfaceId: surfaceId,
            child: child!,
          );
        },
        child: Consumer(
          builder: (_, WidgetRef ref, __) {
            return ref.watch(surfaceWidgetProvider(surfaceId));
          },
        ),
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
    return Consumer(
      builder: (_, WidgetRef ref, Widget? child) {
        final position = ref
            .watch(xdgPopupStatesProvider(surfaceId).select((v) => v.position));
        final visibleBounds = ref.watch(
          xdgSurfaceStatesProvider(surfaceId).select((v) => v.visibleBounds),
        );
        final parentId = ref.watch(
          xdgPopupStatesProvider(surfaceId).select((v) => v.parentViewId),
        );
        // FIXME: cannot use watch because the popup thinks the window is at 0,0 when these bounds change.
        final parentVisibleBounds = ref.read(
          xdgSurfaceStatesProvider(parentId).select((v) => v.visibleBounds),
        );

        final parentRenderBox = ref
            .watch(surfaceStatesProvider(parentId).select((v) => v.textureKey))
            .currentContext
            ?.findRenderObject() as RenderBox?;
        final popupStackRenderBox = ref
            .watch(popupStackGlobalKeyProvider)
            .currentContext
            ?.findRenderObject() as RenderBox?;

        Offset offset;
        if (parentRenderBox != null &&
            popupStackRenderBox != null &&
            parentRenderBox.attached &&
            popupStackRenderBox.attached) {
          final global = parentRenderBox.localToGlobal(position);
          offset = popupStackRenderBox.globalToLocal(global);
        } else {
          offset = position;
        }

        return Positioned(
          left: offset.dx - visibleBounds.left + parentVisibleBounds.left,
          top: offset.dy - visibleBounds.top + parentVisibleBounds.top,
          child: child!,
        );
      },
      child: Consumer(
        builder: (_, WidgetRef ref, Widget? child) {
          final isClosing = ref.watch(
            xdgPopupStatesProvider(surfaceId).select((v) => v.isClosing),
          );
          return IgnorePointer(
            ignoring: isClosing,
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}

class _Animations extends ConsumerStatefulWidget {
  const _Animations({
    required this.surfaceId,
    required this.child,
    super.key,
  });
  final int surfaceId;
  final Widget child;

  @override
  ConsumerState<_Animations> createState() => AnimationsState();
}

class AnimationsState extends ConsumerState<_Animations>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        transformHitTests: false,
        position: _offsetAnimation,
        child: widget.child,
      ),
    );
  }

  late final AnimationController controller = AnimationController(
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 100),
    vsync: this,
  )..forward();

  late final Animation<Offset> _offsetAnimation = Tween<Offset>(
    begin: Offset(
      0,
      -10.0 /
          ref.read(surfaceStatesProvider(widget.surfaceId)).surfaceSize.height,
    ),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    ),
  );

  late final Animation<double> _fadeAnimation = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/* import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.provider.dart';
import 'package:shell/manager/wayland/surface/xdg_surface/xdg_surface.provider.dart';
import 'package:shell/manager/wayland/surface/xdg_toplevel/xdg_toplevel.model.dart';
import 'package:shell/manager/wayland/surface/xdg_toplevel/xdg_toplevel.provider.dart';
import 'package:shell/shared/state/cursor_position/cursor_position.provider.dart';
import 'package:shell/shared/state/window_move/window_move.provider.dart';
import 'package:shell/shared/state/window_position/window_position.provider.dart';
import 'package:shell/shared/state/window_resize/window_resize.provider.dart';
import 'package:shell/shared/state/window_stack/window_stack.provider.dart';
import 'package:shell/shared/state/window_state/window_state.provider.dart';

const duration = Duration(milliseconds: 300);

class Window extends ConsumerStatefulWidget {
  const Window({
    required this.surfaceId,
    super.key,
  });
  final SurfaceId surfaceId;

  @override
  ConsumerState<Window> createState() => _WindowState();
}

class _WindowState extends ConsumerState<Window>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    spawnWindowAtCursor();
  }

  void spawnWindowAtCursor() {
    Future.microtask(() {
      final center = ref.read(cursorPositionProvider);
      final visibleBounds = ref
          .read(xdgSurfaceStatesProvider(widget.surfaceId))
          .visibleBounds
          .size;
      var windowRect = Rect.fromCenter(
        center: center,
        width: visibleBounds.width,
        height: visibleBounds.height,
      );

      final desktopSize = ref
          .read(windowStackProvider)
          .desktopSize; // Offset windowPosition = ref.read(windowPositionProvider(widget.surfaceId));
      final desktopRect = Offset.zero & desktopSize;

      var dx = windowRect.right.clamp(desktopRect.left, desktopRect.right) -
          windowRect.right;
      var dy = windowRect.bottom.clamp(desktopRect.top, desktopRect.bottom) -
          windowRect.bottom;
      windowRect = windowRect.translate(dx, dy);

      dx = windowRect.left.clamp(desktopRect.left, desktopRect.right) -
          windowRect.left;
      dy = windowRect.top.clamp(desktopRect.top, desktopRect.bottom) -
          windowRect.top;
      windowRect = windowRect.translate(dx, dy);

      ref.read(windowPositionProvider(widget.surfaceId).notifier).state =
          windowRect.topLeft;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(
          xdgSurfaceStatesProvider(widget.surfaceId)
              .select((v) => v.visibleBounds), (Rect? previous, Rect next) {
        if (previous != null) {
          final offset = ref
              .read(windowResizeProvider(widget.surfaceId).notifier)
              .computeWindowOffset(previous.size, next.size);
          ref
              .read(windowPositionProvider(widget.surfaceId).notifier)
              .update((state) => state + offset);
        }
      })
      ..listen(
          windowMoveProvider(widget.surfaceId).select((v) => v.movedPosition),
          (_, Offset position) {
        ref.read(windowPositionProvider(widget.surfaceId).notifier).state =
            position;
      });

    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? child) {
        final position = ref.watch(windowPositionProvider(widget.surfaceId));
        const offset = Offset.zero;

        return Positioned(
          left: position.dx - offset.dx,
          top: position.dy - offset.dy,
          child: child!,
        );
      },
      child: _OpenCloseAnimations(
        surfaceId: widget.surfaceId,
        child: RepaintBoundary(
          key: ref.watch(
            windowStateProvider(widget.surfaceId)
                .select((value) => value.repaintBoundaryKey),
          ),
          child: ref.watch(xdgToplevelSurfaceWidgetProvider(widget.surfaceId)),
        ),
      ),
    );
  }
}

class _OpenCloseAnimations extends ConsumerStatefulWidget {
  const _OpenCloseAnimations({
    required this.surfaceId,
    required this.child,
  });
  final SurfaceId surfaceId;
  final Widget child;

  @override
  ConsumerState<_OpenCloseAnimations> createState() =>
      _OpenCloseAnimationsState();
}

class _OpenCloseAnimationsState extends ConsumerState<_OpenCloseAnimations> {
  bool forward = true;

  @override
  Widget build(BuildContext context) {
    ref.listen(windowStackProvider.select((v) => v.animateClosing),
        (ISet<int>? previous, ISet<int> next) async {
      previous ??= ISet();
      if (!previous.contains(widget.surfaceId) &&
          next.contains(widget.surfaceId)) {
        setState(() {
          forward = false;
        });
      }
    });

    return Consumer(
      builder: (context, ref, child) {
        return IgnorePointer(
          ignoring: ref
              .watch(windowStackProvider.select((v) => v.animateClosing))
              .contains(widget.surfaceId),
          child: child,
        );
      },
      child: TweenAnimationBuilder(
        tween: Tween(begin: 0.8, end: forward ? 1.0 : 0.8),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double scale, Widget? child) {
          return Transform.scale(
            scale: scale,
            transformHitTests: false,
            filterQuality: FilterQuality.none,
            child: child,
          );
        },
        child: TweenAnimationBuilder(
          tween: Tween(begin: 0, end: forward ? 1.0 : 0.0),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, num opacity, Widget? child) {
            return Opacity(
              opacity: opacity.toDouble(),
              child: child,
            );
          },
          child: widget.child,
          onEnd: () {
            if (!forward) {
              ref.read(windowStackProvider.notifier).remove(widget.surfaceId);
            }
          },
        ),
      ),
    );
  }
}

class _TilingAnimations extends ConsumerStatefulWidget {
  const _TilingAnimations({
    required this.surfaceId,
    required this.child,
  });
  final SurfaceId surfaceId;
  final Widget child;

  @override
  ConsumerState<_TilingAnimations> createState() => _TilingAnimationsState();
}

class _TilingAnimationsState extends ConsumerState<_TilingAnimations>
    with SingleTickerProviderStateMixin {
  late Size oldSurfaceSize;

  // late AnimationController controller = AnimationController(
  //   vsync: this,
  //   duration: const Duration(milliseconds: 200),
  // )..addStatusListener((status) {
  //     if (status == AnimationStatus.completed) {
  //       ref.read(windowStateProvider(widget.surfaceId).notifier).setSnapshot(null);
  //     }
  //   });

  // final sizeTween = Tween<Size>();

  // late final Animation<Size> sizeAnimation = sizeTween.animate(CurveTween(
  //   curve: Curves.easeOutCubic,
  // ).animate(controller));

  // late final opacityAnimation = Tween<double>(
  //   begin: 0,
  //   end: 1,
  // ).animate(CurveTween(
  //   curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
  // ).animate(controller));

  // @override
  // void dispose() {
  //   controller.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    final surfaceId = widget.surfaceId;

    final surfaceSize = ref
        .watch(wlSurfaceStateProvider(surfaceId).select((v) => v.surfaceSize));

    ref
      ..listen(wlSurfaceStateProvider(surfaceId).select((v) => v.surfaceSize),
          (previous, next) {
        oldSurfaceSize = previous ?? next;
      })

      // print(size);

      // ref.listen(wlSurfaceStateProvider(surfaceId).select((v) => v.surfaceSize), (previous, next) {
      //   sizeTween.begin = previous ?? next;
      //   sizeTween.end = next;
      //
      //   controller
      //     ..reset()
      //     ..forward();
      // });
      ..listen(
          xdgToplevelStatesProvider(surfaceId)
              .select((value) => value.tilingRequested),
          (previous, next) async {
        if (previous == next) {
          return;
        }

        if (next == Tiling.maximized) {
          ref.read(windowPositionProvider(surfaceId).notifier).state =
              Offset.zero;
        } else {
          ref.read(windowPositionProvider(surfaceId).notifier).state =
              const Offset(500, 500);
        }

        final renderObjectKey =
            ref.read(windowStateProvider(surfaceId)).repaintBoundaryKey;
        final boundary = renderObjectKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) {
          return;
        }

        final image = boundary.toImageSync();
        ref.read(windowStateProvider(surfaceId).notifier).setSnapshot(image);
      });

    final snapshot = ref.read(windowStateProvider(surfaceId)).snapshot;

    if (snapshot == null) {
      print('snapshot not ready');
      return widget.child;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        TweenAnimationBuilder(
          tween: SizeTween(begin: oldSurfaceSize, end: surfaceSize),
          duration: duration,
          curve: Curves.easeInOutCubic,
          builder: (context, value, child) {
            final scaleX = value!.width / surfaceSize.width;
            final scaleY = value.height / surfaceSize.height;

            return Transform.scale(
              alignment: Alignment.topLeft,
              scaleX: scaleX,
              scaleY: scaleY,
              child: child,
            );

            // return TransformBox(
            //   from: visibleBounds,
            //   to: value,
            //   child: CropOverflowBox(
            //     rect: oldSurfaceSize,
            //     child: child!,
            //   ),
            // );

            // return Transform.translate(
            //   offset: Offset((value.left - visibleBounds.left) * scaleX, (value.top - visibleBounds.top) * scaleY),
            //   child: Transform.scale(
            //     alignment: Alignment.topLeft,
            //     transformHitTests: false,
            //     scaleX: scaleX,
            //     scaleY: scaleY,
            //     child: child,
            //   ),
            // );
          },
          child: widget.child,
        ),
        TweenAnimationBuilder(
          key: ValueKey(snapshot),
          tween: SizeTween(
            begin: Size(snapshot.width.toDouble(), snapshot.height.toDouble()),
            end: surfaceSize,
          ),
          duration: duration,
          curve: Curves.easeInOutCubic,
          builder: (context, value, child) {
            return SizedBox(
              width: value!.width,
              height: value.height,
              child: child,
            );
          },
          child: TweenAnimationBuilder(
            tween: Tween(begin: 1, end: 0),
            duration: duration,
            curve: const Interval(0.3, 0.7, curve: Curves.easeInOutCubic),
            builder: (context, value, child) {
              return Opacity(
                opacity: value.toDouble(),
                child: child,
              );
            },
            child: IgnorePointer(
              child: RawImage(
                fit: BoxFit.fill,
                image: snapshot,
              ),
            ),
            onEnd: () {
              ref
                  .read(windowStateProvider(widget.surfaceId).notifier)
                  .setSnapshot(null);
            },
          ),
        ),
        // AnimatedBuilder(
        //   animation: sizeAnimation,
        //   builder: (context, child) {
        //     return SizedBox(
        //       width: sizeAnimation.value.width,
        //       height: sizeAnimation.value.height,
        //       child: child,
        //     );
        //   },
        //   child: AnimatedBuilder(
        //     animation: opacityAnimation,
        //     builder: (BuildContext context, Widget? child) {
        //       return Opacity(
        //         opacity: 1 - opacityAnimation.value,
        //         child: child,
        //       );
        //     },
        //     child: IgnorePointer(
        //       child: RawImage(
        //         fit: BoxFit.fill,
        //         image: snapshot,
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }
}

// import 'dart:ui' as ui;
//
// import 'package:fast_immutable_collections/fast_immutable_collections.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:hooks_riverpod/hooks_riverpod.dart';// import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:shell/ui/common/state/surface_state.dart';
// import 'package:shell/ui/common/state/xdg_surface_state.dart';
// import 'package:shell/ui/common/state/xdg_toplevel_state.dart';
// import 'package:shell/ui/desktop/decorations/with_decorations.dart';
// import 'package:shell/ui/desktop/interactive_move_and_resize_listener.dart';
// import 'package:shell/ui/desktop/state/cursor_position_provider.dart';
// import 'package:shell/ui/desktop/state/window_move_provider.dart';
// import 'package:shell/ui/desktop/state/window_position_provider.dart';
// import 'package:shell/ui/desktop/state/window_resize_provider.dart';
// import 'package:shell/ui/desktop/state/window_stack_provider.dart';
// import 'package:shell/ui/desktop/state/window_state_provider.dart';
// import 'package:shell/ui/mobile/state/virtual_keyboard_state.dart';
//
// part 'window.g.dart';
//
// @Riverpod(keepAlive: true)
// Window windowWidget(WindowWidgetRef ref, SurfaceId surfaceId) {
//   return Window(
//     key: GlobalKey(),
//     surfaceId: surfaceId,
//   );
// }
//
// class Window extends ConsumerStatefulWidget {
//   final SurfaceId surfaceId;
//
//   const Window({
//     super.key,
//     required this.surfaceId,
//   });
//
//   @override
//   ConsumerState<Window> createState() => _WindowState();
// }
//
// class _WindowState extends ConsumerState<Window> with SingleTickerProviderStateMixin {
//   @override
//   void initState() {
//     super.initState();
//     spawnWindowAtCursor();
//   }
//
//   void spawnWindowAtCursor() {
//     Future.microtask(() {
//       Offset center = ref.read(cursorPositionProvider);
//       Size surfaceSize = ref.read(wlSurfaceStateProvider(widget.surfaceId)).surfaceSize;
//       Rect windowRect = Rect.fromCenter(
//         center: center,
//         width: surfaceSize.width,
//         height: surfaceSize.height,
//       );
//
//       Size desktopSize = ref.read(windowStackProvider).desktopSize;// Offset windowPosition = ref.read(windowPositionProvider(widget.surfaceId));
//       Rect desktopRect = Offset.zero & desktopSize;
//
//       double dx = windowRect.right.clamp(desktopRect.left, desktopRect.right) - windowRect.right;
//       double dy = windowRect.bottom.clamp(desktopRect.top, desktopRect.bottom) - windowRect.bottom;
//       windowRect = windowRect.translate(dx, dy);
//
//       dx = windowRect.left.clamp(desktopRect.left, desktopRect.right) - windowRect.left;
//       dy = windowRect.top.clamp(desktopRect.top, desktopRect.bottom) - windowRect.top;
//       windowRect = windowRect.translate(dx, dy);
//
//       ref.read(windowPositionProvider(widget.surfaceId).notifier).state = windowRect.topLeft;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     ref.listen(xdgSurfaceStatesProvider(widget.surfaceId).select((v) => v.visibleBounds), (Rect? previous, Rect next) {
//       if (previous != null) {
//         Offset offset =
//             ref.read(windowResizeProvider(widget.surfaceId).notifier).computeWindowOffset(previous.size, next.size);
//         ref.read(windowPositionProvider(widget.surfaceId).notifier).update((state) => state + offset);
//       }
//     });
//
//     ref.listen(windowMoveProvider(widget.surfaceId).select((v) => v.movedPosition), (_, Offset position) {
//       ref.read(windowPositionProvider(widget.surfaceId).notifier).state = position;
//     });
//
//     // Initialize the provider because it listens to events from other providers.
//     ref.read(virtualKeyboardStateNotifierProvider(widget.surfaceId));
//
//     return Consumer(
//       builder: (BuildContext context, WidgetRef ref, Widget? child) {
//         final offset = ref.watch(windowPositionProvider(widget.surfaceId));
//         return Positioned(
//           left: offset.dx,
//           top: offset.dy,
//           child: child!,
//         );
//       },
//       child: _OpenCloseAnimations(
//         surfaceId: widget.surfaceId,
//         child: _TilingAnimations(
//           surfaceId: widget.surfaceId,
//           child: RepaintBoundary(
//             key: ref.watch(windowStateProvider(widget.surfaceId).select((value) => value.repaintBoundaryKey)),
//             child: WithDecorations(
//               surfaceId: widget.surfaceId,
//               child: InteractiveMoveAndResizeListener(
//                 surfaceId: widget.surfaceId,
//                 child: ref.watch(xdgToplevelSurfaceWidgetProvider(widget.surfaceId)),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _OpenCloseAnimations extends ConsumerStatefulWidget {
//   final SurfaceId surfaceId;
//   final Widget child;
//
//   const _OpenCloseAnimations({
//     required this.surfaceId,
//     required this.child,
//   });
//
//   @override
//   ConsumerState<_OpenCloseAnimations> createState() => _OpenCloseAnimationsState();
// }
//
// class _OpenCloseAnimationsState extends ConsumerState<_OpenCloseAnimations> with SingleTickerProviderStateMixin {
//   late var controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
//   late var scaleAnimation = Tween(begin: 0.8, end: 1.0).animate(
//     CurvedAnimation(
//       parent: controller,
//       curve: Curves.easeOutCubic,
//       reverseCurve: Curves.easeInCubic,
//     ),
//   );
//   late var opacityAnimation = Tween(begin: 0.0, end: 1.0).animate(
//     CurvedAnimation(
//       parent: controller,
//       curve: Curves.easeOutCubic,
//       reverseCurve: Curves.easeInCubic,
//     ),
//   );
//
//   @override
//   void initState() {
//     super.initState();
//     controller.forward();
//   }
//
//   @override
//   void dispose() {
//     controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     ref.listen(windowStackProvider.select((v) => v.animateClosing), (ISet<int>? previous, ISet<int> next) async {
//       previous ??= ISet();
//       if (!previous.contains(widget.surfaceId) && next.contains(widget.surfaceId)) {
//         await controller.reverse().orCancel;
//         ref.read(windowStackProvider.notifier).remove(widget.surfaceId);
//       }
//     });
//
//     return Consumer(
//       builder: (context, ref, child) {
//         return IgnorePointer(
//           ignoring: ref.watch(windowStackProvider.select((v) => v.animateClosing)).contains(widget.surfaceId),
//           child: child!,
//         );
//       },
//       child: AnimatedBuilder(
//         animation: scaleAnimation,
//         builder: (BuildContext context, Widget? child) {
//           return Transform.scale(
//             scale: scaleAnimation.value,
//             transformHitTests: false,
//             filterQuality: FilterQuality.none,
//             child: child,
//           );
//         },
//         child: AnimatedBuilder(
//           animation: opacityAnimation,
//           builder: (BuildContext context, Widget? child) {
//             return Opacity(
//               opacity: opacityAnimation.value,
//               child: child,
//             );
//           },
//           child: widget.child,
//         ),
//       ),
//     );
//   }
// }
//
// class _TilingAnimations extends ConsumerStatefulWidget {
//   final SurfaceId surfaceId;
//   final Widget child;
//
//   const _TilingAnimations({
//     required this.surfaceId,
//     required this.child,
//   });
//
//   @override
//   ConsumerState<_TilingAnimations> createState() => _TilingAnimationsState();
// }
//
// class _TilingAnimationsState extends ConsumerState<_TilingAnimations> with SingleTickerProviderStateMixin {
//   late AnimationController controller = AnimationController(
//     vsync: this,
//     duration: const Duration(milliseconds: 1000),
//   )..addStatusListener((status) {
//       if (status == AnimationStatus.completed) {
//         ref.read(windowStateProvider(widget.surfaceId).notifier).setSnapshot(null);
//       }
//     });
//
//   final sizeTween = Tween<Size>();
//
//   late final Animation<Size> sizeAnimation = sizeTween.animate(CurveTween(
//     curve: Curves.easeOutCubic,
//   ).animate(controller));
//
//   late final opacityAnimation = Tween<double>(
//     begin: 0,
//     end: 1,
//   ).animate(CurveTween(
//     curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
//   ).animate(controller));
//
//   @override
//   void dispose() {
//     controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final SurfaceId surfaceId = widget.surfaceId;
//
//     Size surfaceSize = ref.watch(wlSurfaceStateProvider(surfaceId).select((v) => v.surfaceSize));
//
//     ref.listen(wlSurfaceStateProvider(surfaceId).select((v) => v.surfaceSize), (previous, next) {
//       sizeTween.begin = previous ?? next;
//       sizeTween.end = next;
//
//       controller
//         ..reset()
//         ..forward();
//     });
//
//     ref.listen(xdgToplevelStatesProvider(surfaceId).select((value) => value.tilingRequested), (previous, next) async {
//       if (previous == next) {
//         return;
//       }
//
//       final renderObjectKey = ref.read(windowStateProvider(surfaceId)).repaintBoundaryKey;
//       RenderRepaintBoundary? boundary = renderObjectKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
//       if (boundary == null) {
//         return;
//       }
//
//       final image = boundary.toImageSync();
//       ref.read(windowStateProvider(surfaceId).notifier).setSnapshot(image);
//     });
//
//     ui.Image? snapshot = ref.read(windowStateProvider(surfaceId)).snapshot;
//
//     if (snapshot == null) {
//       print("snapshot not ready");
//       return widget.child;
//     }
//
//     return Stack(
//       fit: StackFit.passthrough,
//       children: [
//         AnimatedBuilder(
//           animation: sizeAnimation,
//           builder: (context, child) {
//             return Transform.scale(
//               alignment: Alignment.topLeft,
//               transformHitTests: false,
//               scaleX: sizeAnimation.value.width / surfaceSize.width,
//               scaleY: sizeAnimation.value.height / surfaceSize.height,
//               child: child,
//             );
//           },
//           child: widget.child,
//         ),
//         AnimatedBuilder(
//           animation: sizeAnimation,
//           builder: (context, child) {
//             return SizedBox(
//               width: sizeAnimation.value.width,
//               height: sizeAnimation.value.height,
//               child: child,
//             );
//           },
//           child: AnimatedBuilder(
//             animation: opacityAnimation,
//             builder: (BuildContext context, Widget? child) {
//               return Opacity(
//                 opacity: 1 - opacityAnimation.value,
//                 child: child,
//               );
//             },
//             child: IgnorePointer(
//               child: RawImage(
//                 fit: BoxFit.fill,
//                 image: snapshot,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
 */
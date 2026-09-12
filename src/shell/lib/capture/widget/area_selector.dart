import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, PlatformException;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/capture/provider/capture_selection.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

class AreaSelector extends ConsumerWidget {
  const AreaSelector({required this.monitor, super.key});

  final Monitor monitor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(captureSelectionProvider);
    final bounds = monitor.currentMode == null
        ? null
        : Rect.fromLTWH(
            monitor.location.dx,
            monitor.location.dy,
            monitor.currentMode!.size.width / monitor.scale,
            monitor.currentMode!.size.height / monitor.scale,
          );
    Offset desktopPosition(PointerEvent event) =>
        monitor.location + event.localPosition;
    Offset boundedDesktopPosition(PointerEvent event) {
      final position = desktopPosition(event);
      if (bounds == null) return position;
      return Offset(
        position.dx.clamp(bounds.left, bounds.right),
        position.dy.clamp(bounds.top, bounds.bottom),
      );
    }

    return Positioned.fill(
      child: Focus(
        autofocus: selection.enabled,
        canRequestFocus: selection.enabled,
        onKeyEvent: (node, event) {
          if (selection.enabled &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            ref.read(captureSelectionProvider.notifier).cancel();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: IgnorePointer(
          ignoring: !selection.enabled,
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (event.kind == PointerDeviceKind.mouse &&
                    event.buttons == kPrimaryButton) {
                  ref
                      .read(captureSelectionProvider.notifier)
                      .pointerDown(
                        event.pointer,
                        boundedDesktopPosition(event),
                      );
                }
              },
              onPointerMove: (event) {
                ref
                    .read(captureSelectionProvider.notifier)
                    .pointerMove(event.pointer, boundedDesktopPosition(event));
              },
              onPointerCancel: (_) {
                ref.read(captureSelectionProvider.notifier).cancel();
              },
              onPointerUp: (event) {
                final rect = ref
                    .read(captureSelectionProvider.notifier)
                    .pointerUp(event.pointer, boundedDesktopPosition(event));
                if (rect != null && rect.width >= 1 && rect.height >= 1) {
                  unawaited(_takeScreenshot(ref, rect));
                }
              },
              child: CustomPaint(
                painter: _AreaSelectionPainter(
                  selection: selection.rect,
                  origin: monitor.location,
                  frameRevision: selection.frameRevision,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _takeScreenshot(WidgetRef ref, Rect rect) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final rasterizedFrame = _waitForRasterizedFrame();
      ref.read(captureSelectionProvider.notifier).requestOverlayFreeFrame();
      await rasterizedFrame;

      final platform = ref.read(platformManagerProvider.notifier);
      final revision = ref.read(captureSelectionProvider).layoutRevision;
      final id = await platform.prepareScreenshot(rect, revision);
      ref.read(captureSelectionProvider.notifier).requestOverlayFreeFrame();
      final capture = platform.takePreparedScreenshot(id);
      ref.read(captureSelectionProvider.notifier).requestOverlayFreeFrame();
      await capture;
    } on PlatformException catch (error) {
      debugPrint('Unable to take screenshot: ${error.message}');
    } finally {
      ref.read(captureSelectionProvider.notifier).finishCapture();
    }
  }

  Future<void> _waitForRasterizedFrame() {
    final completed = Completer<void>();
    late void Function(List<FrameTiming>) callback;
    callback = (_) {
      WidgetsBinding.instance.removeTimingsCallback(callback);
      completed.complete();
    };
    WidgetsBinding.instance.addTimingsCallback(callback);
    return completed.future;
  }
}

class _AreaSelectionPainter extends CustomPainter {
  const _AreaSelectionPainter({
    required this.selection,
    required this.origin,
    required this.frameRevision,
  });

  final Rect? selection;
  final Offset origin;
  final int frameRevision;

  @override
  void paint(Canvas canvas, Size size) {
    if (selection == null) {
      // Force an overlay-free Flutter frame without changing the visible
      // pixels.
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0x00000000),
      );
      return;
    }

    final localSelection = selection!.shift(-origin);
    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0x99000000),
      )
      ..drawRect(localSelection, Paint()..blendMode = BlendMode.clear)
      ..restore()
      ..drawRect(
        localSelection,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_AreaSelectionPainter oldDelegate) =>
      selection != oldDelegate.selection ||
      origin != oldDelegate.origin ||
      frameRevision != oldDelegate.frameRevision;
}

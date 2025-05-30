import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/provider/meta_window_dragging_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

class MetaSurfaceDecoration extends HookConsumerWidget {
  const MetaSurfaceDecoration({
    required this.metaWindowId,
    required this.enabled,
    required this.child,
    super.key,
  });
  final bool enabled;
  final Widget child;
  final String metaWindowId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaWindow = ref.watch(metaWindowStateProvider(metaWindowId));

    final surfaceSize = ref.watch(
      wlSurfaceStateProvider(metaWindow.surfaceId).select(
        (v) => v.texture!.size,
      ),
    );

    var height = metaWindow.geometry?.height ?? surfaceSize.height;
    if (metaWindow.geometry?.height != null) {
      height = metaWindow.geometry!.height +
          (metaWindow.needDecoration == true ? 40 : 0);
    }
    if (!enabled) {
      return child;
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      width: metaWindow.geometry?.width ?? surfaceSize.width,
      height: height,
      child: Column(
        children: [
          WindowTitleBar(metaWindowId),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class WindowTitleBar extends HookConsumerWidget {
  const WindowTitleBar(this.metaWindowId, {super.key});
  final String metaWindowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaWindow = ref.watch(metaWindowStateProvider(metaWindowId));
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        print('WindowTitleBar onPanStart');
        ref
            .read(metaWindowDraggingStateProvider(metaWindow.id).notifier)
            .startDragging();
      },
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              const SizedBox(
                width: 16,
              ),
              Text(
                metaWindow.title ?? '',
                style: const TextStyle(color: Colors.white),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  ref
                      .read(metaWindowStateProvider(metaWindowId).notifier)
                      .requestToClose();
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

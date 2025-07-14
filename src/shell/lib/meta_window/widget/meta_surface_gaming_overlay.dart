import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/provider/meta_window_gaming_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:uuid/uuid.dart';

class MetaSurfaceGamingOverlay extends HookConsumerWidget {
  const MetaSurfaceGamingOverlay({required this.metaWindowId, super.key});
  final String metaWindowId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaWindowState = ref.watch(metaWindowStateProvider(metaWindowId));
    final heroUuid = useMemoized(() => const Uuid().v4(), []);

    final zoomToGamingMode = useCallback(
      () {
        ref.read(metaWindowGamingStateProvider(metaWindowId).notifier).set(
              MetaWindowGamingStatus.running,
            );

        Navigator.of(context, rootNavigator: true).push(
          PageRouteBuilder<Hero>(
            opaque: false,
            pageBuilder: (context, _, __) => Consumer(
              builder: (context, ref, child) {
                final metaWindowState =
                    ref.watch(metaWindowStateProvider(metaWindowId));

                ref.listen(
                    metaWindowStateProvider(metaWindowId)
                        .select((value) => value.gameModeActivated),
                    (previous, next) {
                  if (next == false) {
                    Navigator.of(context).pop();
                    ref
                        .read(
                          metaWindowGamingStateProvider(metaWindowId).notifier,
                        )
                        .set(
                          MetaWindowGamingStatus.paused,
                        );
                  }
                });
                return Hero(
                  tag: heroUuid,
                  flightShuttleBuilder: (
                    flightContext,
                    animation,
                    flightDirection,
                    fromHeroContext,
                    toHeroContext,
                  ) {
                    return HookBuilder(
                      builder: (context) {
                        useEffect(
                          () {
                            animation.addStatusListener((status) {
                              if (status == AnimationStatus.completed) {
                                ref
                                    .read(
                                      metaWindowStateProvider(metaWindowId)
                                          .notifier,
                                    )
                                    .patch(
                                      UpdateGameModeActivated(
                                        id: metaWindowId,
                                        value: true,
                                      ),
                                    );
                              }
                            });
                            return null;
                          },
                          [],
                        );
                        return FittedBox(
                          child: SizedBox(
                            width: metaWindowState.geometry!.width,
                            height: metaWindowState.geometry!.height,
                            child: toHeroContext.widget,
                          ),
                        );
                      },
                    );
                  },
                  child: MetaSurfaceWidget(
                    metaWindowId: metaWindowState.id,
                    decorated: false,
                  ),
                );
              },
            ),
          ),
        );
      },
      [],
    );

    useEffect(
      () {
        final metaWindowGamingState =
            ref.read(metaWindowGamingStateProvider(metaWindowId));
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          final monitorName = CurrentMonitorName.of(context);
          final monitor = ref.read(
            monitorByNameProvider(monitorName),
          )!;
          final geometry = ref.read(
            metaWindowStateProvider(metaWindowId)
                .select((value) => value.geometry),
          );

          ref
              .read(
                metaWindowStateProvider(metaWindowId).notifier,
              )
              .patch(
                UpdateGeometry(
                  id: metaWindowId,
                  value: Rect.fromLTWH(
                    geometry!.left,
                    geometry.top,
                    monitor.currentMode!.size.width,
                    monitor.currentMode!.size.height,
                  ),
                ),
              );
          if (metaWindowGamingState == MetaWindowGamingStatus.running) {
            zoomToGamingMode();
          }
        });
        return null;
      },
      [],
    );
    return Stack(
      children: [
        Positioned.fill(
          child: Hero(
            tag: heroUuid,
            child: FittedBox(
              child: SizedBox(
                width: metaWindowState.geometry!.width,
                height: metaWindowState.geometry!.height,
                child: MetaSurfaceWidget(
                  metaWindowId: metaWindowId,
                  decorated: false,
                ),
              ),
            ),
          ),
        ),
        if (metaWindowState.gameModeActivated == false) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: zoomToGamingMode,
              child: ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 16,
                      children: [
                        Text(
                          'Gaming Mode in pause',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Click to resume',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

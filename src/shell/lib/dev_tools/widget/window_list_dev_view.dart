import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

class WindowListDevView extends HookConsumerWidget {
  const WindowListDevView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowList = ref.watch(windowManagerProvider);
    return ListView.separated(
      itemBuilder: (context, index) {
        final windowId = windowList[index];
        final state = switch (windowId) {
          PersistentWindowId() =>
            ref.read(persistentWindowStateProvider(windowId)),
          EphemeralWindowId() =>
            ref.read(ephemeralWindowStateProvider(windowId)),
          // TODO: Handle this case.
          DialogWindowId() => throw UnimplementedError(),
        };

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 500,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${state.windowId}'),
                    Text('Type ${state.runtimeType}'),
                    Text('Title: ${state.properties.title}'),
                    Text('AppId: ${state.properties.appId}'),
                    Text('Pid: ${state.properties.pid}'),
                    Text('surfaceId: ${state.metaWindowId}'),
                  ],
                ),
              ),
            ),
/*             SizedBox(
              width: 400,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: FittedBox(
                  child: switch (windowId) {
                    PersistentWindowId() => PersistentWindowTileable(
                        windowId: windowId,
                        isSelected: false,
                      ),
                    EphemeralWindowId() => EphemeralWindowWidget(
                        windowId: windowId,
                        focusNode: FocusNode(),
                      ),
                    DialogWindowId() => const Placeholder(),
                  },
                ),
              ),
            ), */
          ],
        );
      },
      separatorBuilder: (context, index) => const Divider(),
      itemCount: windowList.length,
    );
  }
}

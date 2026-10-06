import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

class WindowListDevView extends HookConsumerWidget {
  const WindowListDevView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowList = ref.watch(
      windowManagerProvider.select((value) => value.windows),
    );
    return ListView.separated(
      itemBuilder: (context, index) {
        final windowId = windowList[index];
        final state = switch (windowId) {
          PersistentWindowId() => ref.read(
            persistentWindowStateProvider(windowId),
          ),
          EphemeralWindowId() => ref.read(
            ephemeralWindowStateProvider(windowId),
          ),
          DialogWindowId() => ref.read(dialogWindowStateProvider(windowId)),
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
                    Text(context.l10n.debugId('${state.windowId}')),
                    Text(context.l10n.debugType('${state.runtimeType}')),
                    Text(context.l10n.debugTitle('${state.properties.title}')),
                    Text(context.l10n.debugAppId('${state.properties.appId}')),
                    Text(context.l10n.debugPid('${state.properties.pid}')),
                    Text(
                      context.l10n.debugMetaWindowId('${state.metaWindowId}'),
                    ),
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

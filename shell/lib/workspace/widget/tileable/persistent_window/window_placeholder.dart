import 'package:flutter/material.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/shared/util/app_launch.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/provider/persistant_window_state.dart';

class WindowPlaceholder extends HookConsumerWidget {
  const WindowPlaceholder({required this.windowId, super.key});
  final PersistentWindowId windowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(persistentWindowStateProvider(windowId));
    final entry = ref
        .watch(
          localizedDesktopEntryForIdProvider(window.appId),
        )
        .value;
    return Material(
      child: InkWell(
        onTap: entry != null
            ? () {
                ref
                    .read(persistentWindowStateProvider(windowId).notifier)
                    .update(window.copyWith(isWaitingForSurface: true));
                launchDesktopEntry(entry.desktopEntry);
              }
            : null,
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 160,
                    width: 160,
                    child: AppIconById(id: window.appId),
                  ),
                  const SizedBox(
                    width: 24,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry?.entries[DesktopEntryKey.name.string] ??
                            'Unknown',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        'Click anywhere to launch',
                        style:
                            Theme.of(context).textTheme.headlineSmall!.copyWith(
                                  color: Theme.of(context).disabledColor,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

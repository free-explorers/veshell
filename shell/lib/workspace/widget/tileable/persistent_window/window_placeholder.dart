import 'package:flutter/material.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/shared/provider/app_launch.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/provider/persistent_window_state.dart';

class WindowPlaceholder extends HookConsumerWidget {
  const WindowPlaceholder({
    required this.windowId,
    required this.tileableFocusNode,
    super.key,
  });

  final PersistentWindowId windowId;
  final FocusNode tileableFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(persistentWindowStateProvider(windowId));
    final entry = window.properties.appId != null
        ? ref
            .watch(
              localizedDesktopEntryForIdProvider(window.properties.appId),
            )
            .value
        : null;

    return Material(
      child: InkWell(
        focusNode: tileableFocusNode,
        onTap: entry != null
            ? () {
                tileableFocusNode.requestFocus();
                ref
                    .read(persistentWindowStateProvider(windowId).notifier)
                    .waitForSurface();
                ref
                    .read(appLaunchProvider.notifier)
                    .launchDesktopEntry(entry.desktopEntry);
              }
            : null,
        child: Stack(
          children: [
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(48),
                  border: Border.all(
                    color: Colors.white24,
                    width: 4,
                  ),
                ),
                padding: const EdgeInsets.all(96),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: AppIconById(id: window.properties.appId),
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
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall!
                              .copyWith(
                                color: Theme.of(context).disabledColor,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

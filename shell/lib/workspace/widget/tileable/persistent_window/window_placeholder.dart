import 'dart:math';

import 'package:flutter/material.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/application/widget/app_icon.dart';
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
      color: Colors.black26,
      child: InkWell(
        focusNode: tileableFocusNode,
        onTap: entry != null
            ? () {
                tileableFocusNode.requestFocus();
                ref
                    .read(persistentWindowStateProvider(windowId).notifier)
                    .launchSelf();
              }
            : null,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final parent =
                  constraints.biggest.width > constraints.biggest.height
                      ? Row.new
                      : Column.new;

              final paddingValue = EdgeInsets.all(
                min(96, constraints.biggest.shortestSide / 8),
              );
              return Padding(
                padding: paddingValue,
                child: Card(
                  color: Color.lerp(
                    Theme.of(context).colorScheme.surface,
                    Colors.white,
                    0.04,
                  )?.withOpacity(0.6),
                  child: Padding(
                    padding: paddingValue,
                    child: parent(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 160,
                          width: 160,
                          child: AppIconById(id: window.properties.appId),
                        ),
                        const SizedBox(
                          width: 24,
                          height: 24,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: parent == Row.new
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.center,
                          children: [
                            Text(
                              entry?.entries[DesktopEntryKey.name.string] ??
                                  'Unknown',
                              style: Theme.of(context).textTheme.headlineLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            Text(
                              'Click to start the application',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall!
                                  .copyWith(
                                    color: Theme.of(context).disabledColor,
                                  ),
                              textAlign: parent == Row.new
                                  ? TextAlign.start
                                  : TextAlign.center,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

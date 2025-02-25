import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';

class WindowPlaceholder extends HookConsumerWidget {
  const WindowPlaceholder({
    required this.isSelected,
    required this.window,
    this.focusNode,
    this.onTap,
    super.key,
  });
  final FocusNode? focusNode;
  final bool isSelected;
  final PersistentWindow window;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appId = window.properties.appId;
    final entry = appId != null
        ? ref
            .watch(
              localizedDesktopEntryForIdProvider(appId),
            )
            .value
        : null;

    useListenable(focusNode ?? Listenable.merge([]));
    final isFocused = focusNode?.hasFocus ?? false;
    final backgroundFocusNode = useFocusNode(debugLabel: 'background InkWell');
    final logs = window.executionLogs ?? [];
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsiveRowColumn =
            constraints.maxWidth > constraints.maxHeight ? Row.new : Column.new;

        final iconHeight = constraints.biggest.shortestSide *
            6 /
            sqrt(
              constraints.biggest.shortestSide / 1.2,
            );
        final iconWidth = constraints.biggest.shortestSide *
            6 /
            sqrt(
              constraints.biggest.shortestSide / 1.2,
            );
        return Stack(
          children: [
            Positioned.fill(
              left: -constraints.biggest.width * 0.3,
              right: -constraints.biggest.width * 0.3,
              top: -constraints.biggest.height * 0.3,
              bottom: -constraints.biggest.height * 0.3,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: 300,
                  sigmaY: 300,
                ),
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: AppIconById(
                    id: appId,
                    constrainedSize: 4,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: InkWell(
                focusNode: backgroundFocusNode,
                canRequestFocus: false,
                onTap: entry != null ? onTap : null,
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface.withAlpha(150),
                ),
              ),
            ),
            Positioned.fill(
              left: constraints.biggest.width * 0.2,
              right: constraints.biggest.width * 0.2,
              top: constraints.biggest.height * 0.2,
              bottom: constraints.biggest.height * 0.2,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isFocused ? 1 : 0.8,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  color: Theme.of(context).colorScheme.surface.withAlpha(150),
                  child: logs.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: ListView.builder(
                            itemBuilder: (context, index) => Text(logs[index]),
                            itemCount: logs.length,
                          ),
                        )
                      : InkWell(
                          canRequestFocus: false,
                          onTap: entry != null ? onTap : null,
                          splashColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha(32),
                          focusColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLow
                              .withAlpha(125),
                          child: Focus(
                            focusNode: focusNode,
                            autofocus: true,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      DisplayModeRow(
                                        selectedMode: window.displayMode,
                                        onSelectionChanged: (mode) => ref
                                            .read(
                                              persistentWindowStateProvider(
                                                window.windowId,
                                              ).notifier,
                                            )
                                            .setDisplayMode(mode),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: responsiveRowColumn == Row.new ? 4 : 5,
                                  child: responsiveRowColumn(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: iconHeight,
                                        width: iconWidth,
                                        child: AppIconById(id: appId),
                                      ),
                                      SizedBox(
                                        width: constraints.biggest.longestSide *
                                            6 /
                                            sqrt(
                                              constraints.biggest.longestSide /
                                                  1.2,
                                            ) /
                                            8,
                                        height: constraints
                                                .biggest.longestSide *
                                            6 /
                                            sqrt(
                                              constraints.biggest.longestSide /
                                                  1.2,
                                            ) /
                                            8,
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            responsiveRowColumn == Row.new
                                                ? CrossAxisAlignment.start
                                                : CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            entry?.entries[DesktopEntryKey
                                                    .name.string] ??
                                                'Unknown',
                                            style: Theme.of(context)
                                                .textTheme
                                                .displayMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(
                                            height: 16,
                                          ),
                                          ExecCommandEditor(
                                            maxWidth:
                                                responsiveRowColumn == Row.new
                                                    ? constraints.maxWidth / 3 -
                                                        iconWidth
                                                    : constraints.maxWidth / 4,
                                            originalExec: entry?.entries[
                                                    DesktopEntryKey
                                                        .exec.string] ??
                                                entry?.entries[DesktopEntryKey
                                                    .tryExec.string] ??
                                                'Unknown',
                                            customExec: window.customExec,
                                            onChanged: (customExec) => ref
                                                .read(
                                                  persistentWindowStateProvider(
                                                    window.windowId,
                                                  ).notifier,
                                                )
                                                .setCustomExec(customExec),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Click to start the application',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall!
                                        .copyWith(
                                          color: isFocused
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Theme.of(context).disabledColor,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ExecCommandEditor extends HookWidget {
  const ExecCommandEditor({
    required this.maxWidth,
    required this.originalExec,
    this.onChanged,
    this.customExec,
    super.key,
  });

  final double maxWidth;
  final String originalExec;
  final String? customExec;

  final void Function(String?)? onChanged;

  @override
  Widget build(BuildContext context) {
    final isEditable = useState(false);
    final textController = useTextEditingController(
      text: customExec ?? originalExec,
    );

    useEffect(
      () {
        textController.text = customExec ?? originalExec;
        return null;
      },
      [customExec, originalExec],
    );

    final focusNode = useFocusNode(skipTraversal: true);
    final submittedCb = useCallback(() {
      isEditable.value = false;
      focusNode.unfocus();
      onChanged?.call(
        textController.text == originalExec ? null : textController.text,
      );
    });
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          clipBehavior: Clip.antiAlias,
          color: Colors.white.withAlpha(12),
          borderRadius: const BorderRadius.all(
            Radius.circular(48),
          ),
          child: InkWell(
            onTap: () {
              if (isEditable.value) return;
              isEditable.value = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) {
                  focusNode.requestFocus();
                  textController.selection = TextSelection.fromPosition(
                    TextPosition(offset: textController.text.length),
                  );
                },
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                  ),
                  child: IntrinsicWidth(
                    child: TextField(
                      onSubmitted: (value) => submittedCb(),
                      enabled: isEditable.value,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          MdiIcons.chevronRight,
                        ),
                        border: const OutlineInputBorder(
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.zero,
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 32,
                        ),
                        suffixIcon: isEditable.value
                            ? null
                            : const Icon(
                                MdiIcons.pencil,
                                size: 20,
                              ),
                      ),
                      controller: textController,
                      focusNode: focusNode,
                    ),
                  ),
                ),
                if (isEditable.value) ...[
                  const SizedBox(
                    width: 4,
                  ),
                  IconButton(
                    onPressed: submittedCb,
                    icon: const Icon(MdiIcons.check),
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (customExec != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              onPressed: () {
                onChanged?.call(null);
              },
              icon: const Icon(MdiIcons.restore),
            ),
          ),
      ],
    );
  }
}

class DisplayModeRow extends StatelessWidget {
  const DisplayModeRow({
    required this.selectedMode,
    this.onSelectionChanged,
    super.key,
  });

  final DisplayMode selectedMode;
  final void Function(DisplayMode)? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: DisplayMode.values
          .map((mode) {
            final selected = mode == selectedMode;
            final icon = switch (mode) {
              DisplayMode.maximized => const Icon(MdiIcons.windowMaximize),
              DisplayMode.fullscreen => const Icon(MdiIcons.fullscreen),
              DisplayMode.game => const Icon(MdiIcons.controller),
              DisplayMode.floating => SvgPicture.asset(
                  'assets/float-symbolic.svg',
                  width: 24,
                  height: 24,
                ),
            };
            return [
              Material(
                clipBehavior: Clip.antiAlias,
                borderRadius: const BorderRadius.all(Radius.circular(24)),
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: InkWell(
                  onTap: selected ? null : () => onSelectionChanged?.call(mode),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: icon,
                      ),
                      if (selected)
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Text(
                            switch (mode) {
                              DisplayMode.maximized => 'Maximized',
                              DisplayMode.game => 'Game',
                              DisplayMode.fullscreen => 'Fullscreen',
                              DisplayMode.floating => 'Floating',
                            },
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (mode !=
                  DisplayMode
                      .values.last) // To avoid adding SizedBox at the end
                const SizedBox(width: 8), // Adjust the width as needed
            ];
          })
          .expand((widget) => widget)
          .toList(),
    );
  }
}

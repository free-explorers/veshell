import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/application/widget/app_icon.dart';

class WindowPlaceholder extends HookConsumerWidget {
  const WindowPlaceholder({
    required this.appId,
    this.focusNode,
    this.onTap,
    super.key,
  });
  final FocusNode? focusNode;
  final String? appId;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = appId != null
        ? ref
            .watch(
              localizedDesktopEntryForIdProvider(appId!),
            )
            .value
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsiveRowColumn =
            constraints.maxWidth > constraints.maxHeight ? Row.new : Column.new;
        return Stack(
          children: [
            Positioned.fill(
              left: -constraints.biggest.width * 0.3,
              right: -constraints.biggest.width * 0.3,
              top: -constraints.biggest.height * 0.3,
              bottom: -constraints.biggest.height * 0.3,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 300, sigmaY: 300),
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: AppIconById(
                    id: appId,
                    constrainedSize: 24,
                  ),
                ),
              ),
            ),
            ColoredBox(
              color: Colors.black12,
              child: InkWell(
                onTap: entry != null ? onTap : null,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: focusNode?.hasFocus ?? false ? 1 : 0.8,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: max(constraints.maxWidth / 3, 448),
                      ),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withOpacity(0.6),
                        child: InkWell(
                          onTap: entry != null ? onTap : null,
                          splashColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha(32),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 24,
                                right: 24,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () {},
                                      label: const Text(
                                        'Maximized',
                                      ),
                                      icon: Icon(MdiIcons.windowMaximize),
                                    ),
                                    const SizedBox(
                                      width: 16,
                                    ),
                                    IconButton(
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            Colors.white.withOpacity(0.05),
                                      ),
                                      onPressed: () {},
                                      icon: Icon(MdiIcons.fullscreen),
                                      //label: const Text('Fullscreen'),
                                    ),
                                    const SizedBox(
                                      width: 16,
                                    ),
                                    IconButton(
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            Colors.white.withOpacity(0.05),
                                      ),
                                      onPressed: () {},
                                      icon: Icon(MdiIcons.controller),
                                      //label: const Text('Game'),
                                    ),
                                    const SizedBox(
                                      width: 16,
                                    ),
                                    IconButton(
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            Colors.white.withOpacity(0.05),
                                      ),
                                      onPressed: () {},
                                      icon: SvgPicture.asset(
                                        'assets/float-symbolic.svg',
                                        width: 24,
                                        height: 24,
                                      ),
                                      //label: const Text('Float'),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 96,
                                  top: 128,
                                  right: 96,
                                  bottom: 148,
                                ),
                                child: responsiveRowColumn(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 196,
                                      width: 196,
                                      child: AppIconById(id: appId),
                                    ),
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
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
                                        Material(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(48),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                  maxWidth: 248,
                                                ),
                                                child: IntrinsicWidth(
                                                  child: TextField(
                                                    enabled: false,
                                                    decoration: InputDecoration(
                                                      prefixIcon: Icon(
                                                        MdiIcons.chevronRight,
                                                      ),
                                                      border:
                                                          const OutlineInputBorder(
                                                        borderSide:
                                                            BorderSide.none,
                                                      ),
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      prefixIconConstraints:
                                                          const BoxConstraints(
                                                        minWidth: 32,
                                                      ),
                                                    ),
                                                    controller:
                                                        TextEditingController(
                                                      text: entry?.entries[
                                                              DesktopEntryKey
                                                                  .exec
                                                                  .string] ??
                                                          entry?.entries[
                                                              DesktopEntryKey
                                                                  .tryExec
                                                                  .string] ??
                                                          'Unknown',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                width: 16,
                                              ),
                                              IconButton(
                                                onPressed: () {},
                                                icon: Icon(MdiIcons.pencil),
                                              ),
                                              const SizedBox(
                                                width: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 54,
                                child: Text(
                                  'Click to start the application',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall!
                                      .copyWith(
                                        color: focusNode?.hasFocus ?? false
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
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'dart:math';

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

    return Material(
      color: Colors.black26,
      child: InkWell(
        focusNode: focusNode,
        onTap: entry != null ? onTap : null,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final responsiveRowColumn =
                  constraints.maxWidth > constraints.maxHeight
                      ? Row.new
                      : Column.new;
              return Center(
                child: Card(
                  color: Color.lerp(
                    Theme.of(context).colorScheme.surface,
                    Colors.white,
                    0.04,
                  )?.withOpacity(0.6),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: max(constraints.maxWidth / 4, 448),
                    ),
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
                            left: 64,
                            top: 96,
                            right: 64,
                            bottom: 128,
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
                                    entry?.entries[
                                            DesktopEntryKey.name.string] ??
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
                                          constraints: const BoxConstraints(
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
                                                  borderSide: BorderSide.none,
                                                ),
                                                contentPadding: EdgeInsets.zero,
                                                prefixIconConstraints:
                                                    const BoxConstraints(
                                                  minWidth: 32,
                                                ),
                                              ),
                                              controller: TextEditingController(
                                                text: entry?.entries[
                                                        DesktopEntryKey
                                                            .exec.string] ??
                                                    entry?.entries[
                                                        DesktopEntryKey
                                                            .tryExec.string] ??
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
                          bottom: 48,
                          child: Text(
                            'Click to start the application',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall!
                                .copyWith(
                                  color: Theme.of(context).disabledColor,
                                ),
                          ),
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

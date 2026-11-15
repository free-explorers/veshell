import 'dart:math' as math;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/screen/provider/workspace_display_mode.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

/// The side of a workspace icon, in logical pixels.
const double workspaceIconSize = 24;

/// The icon of a workspace button, following the `theme.workspaceIcon`
/// setting, unless the workspace has a fixed category.
class WorkspaceIcon extends HookConsumerWidget {
  const WorkspaceIcon({required this.workspaceId, super.key});
  final WorkspaceId workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayMode = ref.watch(currentWorkspaceDisplayModeProvider);
    final workspaceState = ref.watch(workspaceStateProvider(workspaceId));

    final appIdList = useMemoized(
      () => workspaceState.tileableWindowList
          .map(
            (windowId) => ref.read(
              persistentWindowStateProvider(
                windowId,
              ).select((value) => value.properties.appId),
            ),
          )
          .nonNulls
          .toList(),
      [workspaceState.tileableWindowList],
    );

    final forcedCategory = workspaceState.forcedCategory;
    if (forcedCategory != null) return CategoryIcon(category: forcedCategory);
    if (appIdList.isEmpty) return const ShellIcon(MdiIcons.plus);

    final rankedAppIdList = rankApplications(appIdList);
    Widget applicationIcon() => SplitIcon(
      children: [
        for (final appId in rankedAppIdList.take(SplitIcon.maxShares))
          AppIconById(id: appId),
      ],
    );

    return switch (displayMode) {
      WorkspaceDisplayMode.hybrid =>
        rankedAppIdList.length == 1 || workspaceState.category == null
            ? applicationIcon()
            : CategoryIcon(category: workspaceState.category!),
      WorkspaceDisplayMode.category => CategoryIcon(
        category: workspaceState.category ?? WorkspaceCategory.System,
      ),
      WorkspaceDisplayMode.application => applicationIcon(),
    };
  }
}

/// The distinct application ids of [appIdList], the most present first;
/// applications present as often keep the order they first appear in.
List<String> rankApplications(List<String> appIdList) {
  final countMap = <String, int>{};
  for (final appId in appIdList) {
    countMap.update(appId, (count) => count + 1, ifAbsent: () => 1);
  }
  // A map iterates in insertion order, so the index breaks the ties.
  final distinct = countMap.keys.toList();
  return [...distinct]..sort((a, b) {
    final byCount = countMap[b]! - countMap[a]!;
    return byCount != 0 ? byCount : distinct.indexOf(a) - distinct.indexOf(b);
  });
}

/// Shares a square icon between up to [maxShares] icons, each drawn at full
/// size and showing only the part of itself that falls in its share: the
/// left and right halves for two, three wedges of a disc for three (the
/// first on top), the quarters for four, in reading order.
class SplitIcon extends StatelessWidget {
  const SplitIcon({
    required this.children,
    this.size = workspaceIconSize,
    super.key,
  });

  static const int maxShares = 4;

  /// The icons, the one given the first share first; past [maxShares], the
  /// rest are not shown.
  final List<Widget> children;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = children.take(maxShares).toList();
    return SizedBox.square(
      dimension: size,
      child: shown.length <= 1
          ? (shown.isEmpty ? null : shown.single)
          : Stack(
              fit: StackFit.expand,
              children: [
                for (final (index, child) in shown.indexed)
                  ClipPath(
                    clipper: SplitIconShareClipper(
                      index: index,
                      count: shown.length,
                    ),
                    child: child,
                  ),
              ],
            ),
    );
  }
}

/// The share [index] of a [SplitIcon] split [count] ways.
class SplitIconShareClipper extends CustomClipper<Path> {
  const SplitIconShareClipper({required this.index, required this.count});

  final int index;
  final int count;

  /// The gap between two shares, relative to the icon's side.
  static const double gapRatio = 1 / 12;

  @override
  Path getClip(Size size) {
    final side = size.shortestSide;
    final gap = side * gapRatio;
    final half = (side - gap) / 2;
    final far = (side + gap) / 2;
    switch (count) {
      case 2:
        return Path()
          ..addRect(Rect.fromLTWH(index == 0 ? 0 : far, 0, half, side));
      case 3:
        return _wedge(Offset(side / 2, side / 2), side / 2, gap);
      default:
        return Path()..addRect(
          Rect.fromLTWH(
            index.isEven ? 0 : far,
            index < 2 ? 0 : far,
            half,
            half,
          ),
        );
    }
  }

  Path _wedge(Offset center, double radius, double gap) {
    const sweep = 2 * math.pi / 3;
    // The first wedge is centered on the top, the others follow clockwise.
    final start = -math.pi / 2 - sweep / 2 + index * sweep;
    final wedge = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
      )
      ..close();
    final gaps = Path();
    for (final angle in [start, start + sweep]) {
      final rotation = Matrix4.identity()
        ..translateByDouble(center.dx, center.dy, 0, 1)
        ..rotateZ(angle);
      gaps.addPath(
        Path()..addRect(Rect.fromLTWH(0, -gap / 2, radius + gap, gap)),
        Offset.zero,
        matrix4: rotation.storage,
      );
    }
    return Path.combine(PathOperation.difference, wedge, gaps);
  }

  @override
  bool shouldReclip(SplitIconShareClipper oldClipper) =>
      index != oldClipper.index || count != oldClipper.count;
}

/// The menu items of a workspace button: fixing the workspace's icon to a
/// category, or letting it follow the windows.
List<Widget> workspaceButtonMenuChildren(
  BuildContext context,
  WidgetRef ref,
  WorkspaceId workspaceId,
) {
  final l10n = context.l10n;
  final forcedCategory = ref
      .read(workspaceStateProvider(workspaceId))
      .forcedCategory;
  final notifier = ref.read(workspaceStateProvider(workspaceId).notifier);
  final selectedColor = Theme.of(context).colorScheme.primary;
  MenuItemButton item({
    required WorkspaceCategory? category,
    required Widget icon,
    required String label,
  }) => MenuItemButton(
    onPressed: () => notifier.setForcedCategory(category),
    leadingIcon: icon,
    style: MenuItemButton.styleFrom(
      foregroundColor: category == forcedCategory ? selectedColor : null,
    ),
    child: Text(label),
  );
  return [
    SubmenuButton(
      leadingIcon: const ShellIcon(MdiIcons.shapeOutline),
      menuChildren: [
        item(
          category: null,
          icon: const ShellIcon(MdiIcons.autoFix),
          label: l10n.workspaceIconAutomatic,
        ),
        for (final category in WorkspaceCategory.values)
          item(
            category: category,
            icon: CategoryIcon(category: category),
            label: category.localizedName(l10n),
          ),
      ],
      child: Text(l10n.workspaceIcon),
    ),
  ];
}

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({required this.category, super.key});
  final WorkspaceCategory category;
  @override
  Widget build(BuildContext context) => ShellIcon(switch (category) {
    WorkspaceCategory.Game => MdiIcons.gamepad,
    WorkspaceCategory.Development => MdiIcons.codeBraces,
    WorkspaceCategory.Video => MdiIcons.movieOpen,
    WorkspaceCategory.Audio => MdiIcons.music,
    WorkspaceCategory.AudioVideo => MdiIcons.playCircleOutline,
    WorkspaceCategory.Graphics => MdiIcons.palette,
    WorkspaceCategory.Office => MdiIcons.fileDocument,
    WorkspaceCategory.Science => MdiIcons.flask,
    WorkspaceCategory.Education => MdiIcons.school,
    WorkspaceCategory.FileManager => MdiIcons.folder,
    WorkspaceCategory.InstantMessaging => MdiIcons.forum,
    WorkspaceCategory.Network => MdiIcons.web,
    WorkspaceCategory.Settings => MdiIcons.cog,
    WorkspaceCategory.System => MdiIcons.desktopClassic,
    WorkspaceCategory.Utility => MdiIcons.applicationCog,
  });
}

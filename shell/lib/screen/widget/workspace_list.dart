import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/current_screen_id.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/screen/provider/workspace_display_mode.dart';
import 'package:shell/shared/widget/cross_reorderable_list.dart';
import 'package:shell/theme/theme.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:shell/workspace/widget/tileable/persistent_window/persistent_window.dart';

class WorkspaceListView extends HookConsumerWidget {
  const WorkspaceListView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = ref.watch(currentScreenIdProvider);
    final screenState = ref.watch(screenStateProvider(screenId));
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 200),
      upperBound: screenState.workspaceList.length.toDouble(),
      initialValue: screenState.selectedIndex.toDouble(),
      keys: [screenState.workspaceList.length],
    );
    final dropInProgressState = useState(false);
    useEffect(
      () {
        animationController.animateTo(
          screenState.selectedIndex.toDouble(),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
        return null;
      },
      [screenState.selectedIndex],
    );
    return CustomPaint(
      painter: WorkspaceIndicatorPainter(
        controller: animationController,
        index: screenState.selectedIndex.toDouble(),
        length: screenState.workspaceList.length,
        indicator: const WorkspaceIndicator(
          border: Border(right: BorderSide(width: 2, color: Colors.white)),
        ),
        disabled: dropInProgressState.value,
      ),
      child: CrossReorderableList<WorkspaceId>(
        onDropInProgress: (dropInProgress) =>
            dropInProgressState.value = dropInProgress,
        itemBuilder: (context, workspaceId) {
          return WorkspaceListButton(
            workspaceId: workspaceId,
            screenId: screenId,
          );
        },
        dataList: screenState.workspaceList.toList(),
        onListChanged: (workspaceList) {
          if (workspaceList.length < screenState.workspaceList.length) {
            final removedWorkspaceList = screenState.workspaceList
                .where((element) => !workspaceList.contains(element))
                .toList();
            for (final workspaceId in removedWorkspaceList) {
              ref
                  .read(screenStateProvider(screenId).notifier)
                  .removeWorkspace(workspaceId);
            }
          } else if (workspaceList.length > screenState.workspaceList.length) {
            final addedWorkspaceList = workspaceList
                .where(
                  (element) => !screenState.workspaceList.contains(element),
                )
                .toList();
            for (final workspaceId in addedWorkspaceList) {
              ref.read(screenStateProvider(screenId).notifier).insertWorkspace(
                    workspaceId,
                    workspaceList.indexOf(workspaceId),
                  );
            }
          } else {
            ref
                .read(screenStateProvider(screenId).notifier)
                .updateWorkspaceList(
                  workspaceList.toIList(),
                );
          }
        },
      ),
    );
  }
}

class WorkspaceIndicator extends Decoration {
  /// Create an underline style selected tab indicator.
  const WorkspaceIndicator({
    this.backgroundColor = const Color.fromRGBO(255, 255, 255, 0.1),
    this.border = const Border(),
  });
  final Color backgroundColor;

  /// The color and weight of the horizontal line drawn below the selected tab.
  final Border border;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _WorkspaceIndicatorPainter(this, onChanged);
  }

  Rect _indicatorRectFor(Rect rect) {
    final indicator = rect;
    return indicator;
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    return Path()..addRect(_indicatorRectFor(rect));
  }
}

class _WorkspaceIndicatorPainter extends BoxPainter {
  _WorkspaceIndicatorPainter(
    this.decoration,
    super.onChanged,
  );

  final WorkspaceIndicator decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);
    final rect = offset & configuration.size!;
    final backgroundPaint = Paint()..color = decoration.backgroundColor;
    canvas.drawRect(rect, backgroundPaint);
    final Paint paint;

    /* paint = decoration.border.toPaint()..strokeCap = StrokeCap.square;
    final indicator = decoration
        ._indicatorRectFor(
          rect,
        )
        .deflate(decoration.borderSide.width / 2.0); */
    decoration.border.paint(canvas, rect);
    //canvas.drawLine(indicator.topRight, indicator.bottomRight, paint);
  }
}

class WorkspaceIndicatorPainter extends CustomPainter {
  WorkspaceIndicatorPainter({
    required this.index,
    required this.length,
    required this.controller,
    required this.indicator,
    this.disabled = false,
  }) : super(repaint: controller.view);
  final double index;
  final int length;
  final AnimationController controller;
  final Decoration indicator;
  final bool disabled;

  Rect? _currentRect;
  BoxPainter? _painter;
  bool _needsPaint = false;
  void markNeedsPaint() {
    _needsPaint = true;
  }

  void dispose() {
    _painter?.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (disabled) return;
    _needsPaint = false;
    _painter ??= indicator.createBoxPainter(markNeedsPaint);

    final value = controller.view.value;
    final ltr = index > value;
    final from = (ltr ? value.floor() : value.ceil())
        .clamp(0, length); // ignore_clamp_double_lint
    final to = (ltr ? from + 1 : from - 1)
        .clamp(0, length); // ignore_clamp_double_lint

    final fromRect = Rect.fromLTWH(0, panelSize * from, panelSize, panelSize);
    final toRect = Rect.fromLTWH(0, panelSize * to, panelSize, panelSize);
    _currentRect = Rect.lerp(fromRect, toRect, (value - from).abs());
    assert(_currentRect != null);

    final configuration = ImageConfiguration(
      size: _currentRect!.size,
    );

    _painter!.paint(canvas, _currentRect!.topLeft, configuration);
  }

  @override
  bool shouldRepaint(WorkspaceIndicatorPainter old) {
    return _needsPaint ||
        controller != old.controller ||
        index != old.index ||
        indicator != old.indicator ||
        length != old.length ||
        disabled != old.disabled;
  }
}

class WorkspaceListButton extends HookConsumerWidget {
  const WorkspaceListButton({
    required this.workspaceId,
    required this.screenId,
    super.key,
  });
  final WorkspaceId workspaceId;
  final ScreenId screenId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenState = ref.watch(screenStateProvider(screenId));

    return DragTarget<PersistentWindowTileable>(
      onWillAcceptWithDetails: (data) => data is PersistentWindowTileable,
      onAcceptWithDetails: (details) {
        ref
            .read(WorkspaceStateProvider(workspaceId).notifier)
            .addWindow(details.data.windowId);
      },
      builder: (
        context,
        candidateData,
        rejectedData,
      ) {
        return AspectRatio(
          aspectRatio: 1,
          child: IconButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
                candidateData.isNotEmpty
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              foregroundColor: WidgetStatePropertyAll(
                candidateData.isNotEmpty
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
              ),
              shape: WidgetStateProperty.all(
                const RoundedRectangleBorder(),
              ),
            ),
            onPressed: () {
              ref.read(screenStateProvider(screenId).notifier).selectWorkspace(
                    screenState.workspaceList.indexOf(workspaceId),
                  );
            },
            icon: WorkspaceIcon(workspaceId: workspaceId),
          ),
        );
      },
    );
  }
}

class WorkspaceIcon extends HookConsumerWidget {
  const WorkspaceIcon({required this.workspaceId, super.key});
  final WorkspaceId workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceDisplayMode = ref.watch(currentWorkspaceDisplayModeProvider);
    final workspaceState = ref.watch(
      workspaceStateProvider(workspaceId),
    );

    final appIdList = useMemoized(
      () => workspaceState.tileableWindowList
          .map(
            (windowId) => ref.read(
              PersistentWindowStateProvider(windowId)
                  .select((value) => value.properties.appId),
            ),
          )
          .toList(),
      [workspaceState.tileableWindowList],
    ).whereNotNull();

    if (appIdList.isEmpty) return const Icon(MdiIcons.plus);

    switch (workspaceDisplayMode) {
      case WorkspaceDisplayMode.hybrid:
        {
          if (appIdList.length == 1) {
            return SizedBox(
              height: 24,
              width: 24,
              child: AppIconById(id: appIdList.first),
            );
          } else {
            return CategoryIcon(
              category: workspaceState.category,
            );
          }
        }
      case WorkspaceDisplayMode.category:
        {
          return CategoryIcon(
            category: workspaceState.category,
          );
        }
      case WorkspaceDisplayMode.application:
        {
          const numberOfEachAppMap = <String, int>{};
          for (final appId in appIdList) {
            if (numberOfEachAppMap.containsKey(appId)) {
              numberOfEachAppMap[appId] = numberOfEachAppMap[appId]! + 1;
            } else {
              numberOfEachAppMap[appId] = 1;
            }
          }
          final sortedByInstanceAppList =
              numberOfEachAppMap.entries.sorted((a, b) {
            return b.value - a.value;
          }).map((entry) => entry.key);
          return Stack(
            children: [
              for (final appId in sortedByInstanceAppList)
                SizedBox(
                  height: 24,
                  width: 24,
                  child: AppIconById(id: appId),
                ),
            ],
          );
        }
    }
  }
}

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({this.category = WorkspaceCategory.System, super.key});
  final WorkspaceCategory? category;
  @override
  Widget build(BuildContext context) {
    switch (category!) {
      case WorkspaceCategory.Game:
        return const Icon(MdiIcons.gamepad);
      case WorkspaceCategory.Development:
        return const Icon(MdiIcons.codeBraces);
      case WorkspaceCategory.Video:
        return const Icon(MdiIcons.movieOpen);
      case WorkspaceCategory.Audio:
        return const Icon(MdiIcons.music);
      case WorkspaceCategory.AudioVideo:
        return const Icon(MdiIcons.playCircleOutline);
      case WorkspaceCategory.Graphics:
        return const Icon(MdiIcons.palette);
      case WorkspaceCategory.Office:
        return const Icon(MdiIcons.fileDocument);
      case WorkspaceCategory.Science:
        return const Icon(MdiIcons.flask);
      case WorkspaceCategory.Education:
        return const Icon(MdiIcons.school);
      case WorkspaceCategory.FileManager:
        return const Icon(MdiIcons.folder);
      case WorkspaceCategory.InstantMessaging:
        return const Icon(MdiIcons.forum);
      case WorkspaceCategory.Network:
        return const Icon(MdiIcons.web);
      case WorkspaceCategory.Settings:
        return const Icon(MdiIcons.cog);
      case WorkspaceCategory.System:
        return const Icon(MdiIcons.desktopClassic);
      case WorkspaceCategory.Utility:
        return const Icon(MdiIcons.applicationCog);
    }
  }
}

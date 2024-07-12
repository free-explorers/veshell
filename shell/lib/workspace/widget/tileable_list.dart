import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/widget/cross_reorderable_list.dart';
import 'package:shell/workspace/provider/current_workspace_id.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:shell/workspace/widget/tileable/persistent_window/persistent_window.dart';
import 'package:shell/workspace/widget/tileable/tileable.dart';

class TileableListView extends HookConsumerWidget {
  const TileableListView({required this.tileableList, super.key});
  final List<Tileable> tileableList;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(currentWorkspaceIdProvider);
    final workspaceState = ref.watch(workspaceStateProvider(workspaceId));
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 200),
      upperBound: workspaceState.tileableWindowList.length.toDouble(),
      initialValue: workspaceState.selectedIndex.toDouble(),
      keys: [tileableList.length],
    );
    final dropInProgressState = useState(false);

    final tileableKeyList = useMemoized(
      () => tileableList.map((Widget tab) => GlobalKey()).toList(),
      [tileableList],
    );

    final offsetMap = useState(
      IMap<GlobalKey, Offset>(),
    );
    useEffect(
      () {
        animationController.animateTo(
          workspaceState.selectedIndex.toDouble(),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
        return null;
      },
      [workspaceState.selectedIndex],
    );

    final listKey = useMemoized(GlobalKey.new);

    Widget buildItem(BuildContext context, Tileable tileable) {
      final index = tileableList.indexOf(tileable);
      return SizedBox(
        height: double.infinity,
        child: InkWell(
          onTap: () => ref
              .read(workspaceStateProvider(workspaceId).notifier)
              .setSelectedIndex(
                index,
              ),
          child: tileable.buildPanelWidget(context, ref),
        ),
      );
    }

    return CustomPaint(
      painter: TileableIndicatorPainter(
        controller: animationController,
        index: workspaceState.selectedIndex,
        tileableKeyList: tileableKeyList,
        listKey: listKey,
        length: tileableList.length,
        offsetMap: offsetMap.value,
        indicator: const TileableIndicator(
          border: Border(bottom: BorderSide(width: 2, color: Colors.white)),
        ),
        disabled: dropInProgressState.value,
      ),
      child: CrossReorderableList<Tileable>(
        key: listKey,
        scrollDirection: Axis.horizontal,
        onDropInProgress: (dropInProgress) =>
            dropInProgressState.value = dropInProgress,
        itemBuilder: (context, tileable) {
          // if dropInProgress the tileable could not be in the list
          // so we don't try to record it offset and display a normal item
          if (dropInProgressState.value) return buildItem(context, tileable);
          final index = tileableList.indexOf(tileable);
          return LayoutBuilder(
            key: tileableKeyList[index],
            builder: (context, constraints) {
              // call with delay to prevent FlutterError (setState() or markNeedsBuild() called during build.
              Future.delayed(Duration.zero, () {
                final renderBox = tileableKeyList[index]
                    .currentContext!
                    .findRenderObject()! as RenderBox;
                final offset = renderBox.localToGlobal(Offset.zero);
                if (offset != offsetMap.value[tileableKeyList[index]]) {
                  offsetMap.value = offsetMap.value.add(
                    tileableKeyList[index],
                    renderBox.localToGlobal(Offset.zero),
                  );
                }
              });
              return buildItem(context, tileable);
            },
          );
        },
        feedbackBuilder: (context, tileable) => Material(
          color: Colors.transparent,
          child: buildItem(context, tileable),
        ),
        dataList: tileableList.toList(),
        onListChanged: (updatedTileableList) {
          if (updatedTileableList.length > tileableList.length) {
            final addedTileableList = updatedTileableList
                .where(
                  (element) => !tileableList.contains(element),
                )
                .toList();
            for (final tileable in addedTileableList) {
              if (tileable is PersistentWindowTileable) {
                ref
                    .read(workspaceStateProvider(workspaceId).notifier)
                    .insertWindow(
                      tileable.windowId,
                      updatedTileableList.indexOf(tileable),
                    );
              }
            }
          } else if (updatedTileableList.length < tileableList.length) {
            final removedTileableList = tileableList
                .where((element) => !updatedTileableList.contains(element))
                .toList();
            for (final tileable in removedTileableList) {
              if (tileable is PersistentWindowTileable) {
                ref
                    .read(workspaceStateProvider(workspaceId).notifier)
                    .removeWindow(
                      tileable.windowId,
                    );
              }
            }
          } else {
            ref
                .read(workspaceStateProvider(workspaceId).notifier)
                .reorderWindowList(
                  updatedTileableList
                      .whereType<PersistentWindowTileable>()
                      .map((e) => e.windowId)
                      .toIList(),
                );
          }
        },
      ),
    );
  }
}

/// A decoration painted behind the selected tab
class TileableIndicator extends Decoration {
  ///
  const TileableIndicator({
    this.backgroundColor = const Color.fromRGBO(255, 255, 255, 0.1),
    this.border = const Border(),
  });
  final Color backgroundColor;

  /// The color and weight of the line drawn below the selected tab.
  final Border border;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _TileableIndicatorPainter(this, onChanged);
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

class _TileableIndicatorPainter extends BoxPainter {
  _TileableIndicatorPainter(
    this.decoration,
    super.onChanged,
  );

  final TileableIndicator decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);
    final rect = offset & configuration.size!;
    final backgroundPaint = Paint()..color = decoration.backgroundColor;
    canvas.drawRect(rect, backgroundPaint);
    decoration.border.paint(canvas, rect);
  }
}

/// This CustomPainter is inspired from the TabBarIndicator
/// We keep track of the tabs offset and size to draw the indicator
class TileableIndicatorPainter extends CustomPainter {
  ///
  TileableIndicatorPainter({
    required this.index,
    required this.length,
    required this.controller,
    required this.indicator,
    required this.tileableKeyList,
    required this.listKey,
    required this.offsetMap,
    this.disabled = false,
  }) : super(repaint: controller.view);

  /// The index of the tab that is currently selected.
  final int index;

  /// The total number of tabs.
  final int length;

  /// The animation controller animating the selected tab indicator.
  final AnimationController controller;

  /// The decoration of the selected tab indicator.
  final Decoration indicator;

  /// Whether the indicator is disabled.
  final bool disabled;

  /// The list of keys for the tabs.
  final List<GlobalKey> tileableKeyList;

  /// The key of the list containing the tabs.
  final GlobalKey listKey;

  /// The offset of the tabs.
  final IMap<GlobalKey, Offset> offsetMap;

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
    final listBox = listKey.currentContext!.findRenderObject()! as RenderBox;
    final listOffset = listBox.localToGlobal(Offset.zero);
    final value = controller.view.value;
    final ltr = index > value;

    final from = (ltr ? value.floor() : value.ceil())
        .clamp(0, length); // ignore_clamp_double_lint
    final to = (ltr ? from + 1 : from - 1)
        .clamp(0, length); // ignore_clamp_double_lint

    // from
    final fromKey = tileableKeyList[from];
    RenderBox? fromBox;
    try {
      fromBox = fromKey.currentContext?.findRenderObject() as RenderBox?;
    } catch (e) {
      fromBox = null;
    }
    final fromRelativeOffset = (offsetMap.get(fromKey) ??
            fromBox?.localToGlobal(Offset.zero) ??
            Offset.zero) -
        listOffset;
    final fromRect = Rect.fromLTWH(
      fromRelativeOffset.dx,
      fromRelativeOffset.dy,
      fromBox?.size.width ?? 0,
      fromBox?.size.height ?? size.height,
    );

    // to
    final toKey = tileableKeyList[to];
    RenderBox? toBox;
    try {
      toBox = toKey.currentContext?.findRenderObject() as RenderBox?;
    } catch (e) {
      toBox = null;
    }
    final toRelativeOffset = (offsetMap.get(toKey) ??
            toBox?.localToGlobal(Offset.zero) ??
            Offset.zero) -
        listOffset;
    final toRect = Rect.fromLTWH(
      toRelativeOffset.dx,
      toRelativeOffset.dy,
      toBox?.size.width ?? 0,
      toBox?.size.height ?? size.height,
    );

    _currentRect = Rect.lerp(fromRect, toRect, (value - from).abs());
    assert(_currentRect != null);

    final configuration = ImageConfiguration(
      size: _currentRect!.size,
    );

    _painter!.paint(canvas, _currentRect!.topLeft, configuration);
  }

  @override
  bool shouldRepaint(TileableIndicatorPainter oldDelegate) {
    return _needsPaint ||
        controller != oldDelegate.controller ||
        index != oldDelegate.index ||
        indicator != oldDelegate.indicator ||
        length != oldDelegate.length ||
        disabled != oldDelegate.disabled ||
        offsetMap != oldDelegate.offsetMap;
  }
}

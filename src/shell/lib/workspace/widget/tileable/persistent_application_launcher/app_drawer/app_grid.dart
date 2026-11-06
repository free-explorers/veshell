import 'dart:math' as math;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/launch_morph.dart';

/// Desktop entry selected callback
typedef DesktopEntrySelectedCallback =
    void Function(LocalizedDesktopEntry desktopEntry);

/// A launcher item was launched; [origin] is where it sits on screen, when
/// known, for the opening morph.
typedef DesktopEntryLaunchCallback =
    void Function(LocalizedDesktopEntry desktopEntry, LaunchOrigin? origin);

/// The item at [index] of a grid or row was launched.
typedef AppItemLaunchCallback =
    void Function(
      int index,
      LocalizedDesktopEntry desktopEntry,
      LaunchOrigin? origin,
    );

/// Reports where the item `Enter` would launch sits on screen.
typedef LaunchOriginGetter = LaunchOrigin? Function();

const _maxTileExtent = 120.0;
const _tileAspectRatio = 0.8;
const _tileSpacing = 16.0;

/// The number of columns of an [AppGridSliver] whose content is [width]
/// wide: as many tiles of at most [_maxTileExtent] as fit, at least one.
int appGridColumnCount(double width) => math.max(
  1,
  ((width + _tileSpacing) / (_maxTileExtent + _tileSpacing)).ceil(),
);

/// The size of one tile in a grid of [columnCount] columns whose content is
/// [width] wide.
Size appGridTileSize(double width, int columnCount) {
  final tileWidth =
      (math.max(0, width) - (columnCount - 1) * _tileSpacing) / columnCount;
  return Size(tileWidth, tileWidth / _tileAspectRatio);
}

/// Where each entry of consecutive sections of [sectionLengths] entries
/// (flattened, in order) sits in rows of [columnCount] columns: its section,
/// its row counted across every section, and its column. Each section starts
/// a new row.
List<({int section, int row, int column})> appGridCells(
  List<int> sectionLengths,
  int columnCount,
) {
  final cells = <({int section, int row, int column})>[];
  var firstRow = 0;
  for (final (section, length) in sectionLengths.indexed) {
    for (var index = 0; index < length; index++) {
      cells.add((
        section: section,
        row: firstRow + index ~/ columnCount,
        column: index % columnCount,
      ));
    }
    firstRow += (length / columnCount).ceil();
  }
  return cells;
}

/// The flattened index reached from [index] by moving [rows] rows up
/// (negative) or down, keeping the column where the target row is long enough
/// and taking its last entry otherwise; `null` past the first or last row.
int? appGridMoveVertically(
  List<({int section, int row, int column})> cells,
  int index,
  int rows,
) {
  final (section: _, :row, :column) = cells[index];
  final targetRow = row + rows;
  int? target;
  for (final (candidate, cell) in cells.indexed) {
    if (cell.row == targetRow && cell.column <= column) {
      target = candidate;
    }
  }
  return target;
}

/// Application grid, as a sliver, with the keyboard selection highlighted.
///
/// A sliver so the grid scrolls with the rest of the launcher tile: browsing
/// gets the whole tile, and the grid still builds only the visible tiles.
class AppGridSliver extends StatelessWidget {
  /// Const constructor
  const AppGridSliver({
    required this.entryList,
    required this.columnCount,
    required this.selectedIndex,
    required this.onLaunch,
    this.query = '',
    this.padding = 24,
    this.launchTargetIndex,
    this.launchTarget,
    super.key,
  });

  final List<LocalizedDesktopEntry> entryList;

  final int columnCount;

  /// The highlighted entry, scrolled into view; `null` highlights nothing.
  final int? selectedIndex;

  /// The search, whose matches are emphasized in the names.
  final String query;

  final AppItemLaunchCallback onLaunch;

  /// The entry `Enter` launches (highlighted or not), which records how to
  /// find where it sits in [launchTarget].
  final int? launchTargetIndex;

  final ObjectRef<LaunchOriginGetter?>? launchTarget;

  final double padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.all(padding),
      sliver: SliverGrid.builder(
        itemCount: entryList.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
          childAspectRatio: _tileAspectRatio,
          crossAxisSpacing: _tileSpacing,
          mainAxisSpacing: _tileSpacing,
        ),
        itemBuilder: (context, index) {
          final entry = entryList[index];
          return AppEntry(
            key: ValueKey(entry.desktopEntry.id),
            desktopEntry: entry,
            query: query,
            isSelected: index == selectedIndex,
            launchTarget: index == launchTargetIndex ? launchTarget : null,
            onLaunch: (entry, origin) => onLaunch(index, entry, origin),
          );
        },
      ),
    );
  }
}

/// One row of application tiles, sized like those of an [AppGridSliver] of
/// [columnCount] columns, so the two line up when stacked.
class AppRow extends StatelessWidget {
  const AppRow({
    required this.entryList,
    required this.columnCount,
    required this.selectedIndex,
    required this.onLaunch,
    this.padding = 24,
    this.launchTargetIndex,
    this.launchTarget,
    super.key,
  });

  /// The entries; past [columnCount] they are left out.
  final List<LocalizedDesktopEntry> entryList;

  final int columnCount;

  /// The highlighted entry; `null` highlights nothing.
  final int? selectedIndex;

  final AppItemLaunchCallback onLaunch;

  /// See [AppGridSliver.launchTargetIndex].
  final int? launchTargetIndex;

  final ObjectRef<LaunchOriginGetter?>? launchTarget;

  final double padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tile = appGridTileSize(
          constraints.maxWidth - 2 * padding,
          columnCount,
        );
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            spacing: _tileSpacing,
            children: [
              for (final (index, entry) in entryList.take(columnCount).indexed)
                SizedBox.fromSize(
                  size: tile,
                  child: AppEntry(
                    key: ValueKey(entry.desktopEntry.id),
                    desktopEntry: entry,
                    isSelected: index == selectedIndex,
                    launchTarget: index == launchTargetIndex
                        ? launchTarget
                        : null,
                    onLaunch: (entry, origin) => onLaunch(index, entry, origin),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Application entry
class AppEntry extends HookWidget {
  /// Const constructor
  const AppEntry({
    required this.desktopEntry,
    required this.onLaunch,
    this.isSelected = false,
    this.query = '',
    this.launchTarget,
    super.key,
  });

  /// Desktop entry
  final LocalizedDesktopEntry desktopEntry;

  /// Whether the keyboard selection is on this entry (`Enter` launches it).
  final bool isSelected;

  /// The search, whose matches are emphasized in the name.
  final String query;

  final DesktopEntryLaunchCallback onLaunch;

  /// Set when `Enter` would launch this entry: it records there how to find
  /// where it sits, so the launch can start the opening morph from it.
  final ObjectRef<LaunchOriginGetter?>? launchTarget;

  @override
  Widget build(BuildContext context) {
    final iconKey = useMemoized(GlobalKey.new);
    final labelKey = useMemoized(GlobalKey.new);

    LaunchOrigin? origin() {
      Rect? rectOf(BuildContext? of) {
        if (of == null || !of.mounted) {
          return null;
        }
        final box = of.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize) {
          return null;
        }
        return box.localToGlobal(Offset.zero) & box.size;
      }

      final item = rectOf(context);
      final icon = rectOf(iconKey.currentContext);
      final label = rectOf(labelKey.currentContext);
      if (item == null || icon == null || label == null) {
        return null;
      }
      return (item: item, icon: icon, label: label);
    }

    launchTarget?.value = origin;

    // The keyboard selection scrolls into view, by the least scroll that
    // reveals it, through every enclosing scrollable.
    useEffect(() {
      if (isSelected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.findRenderObject()?.showOnScreen();
          }
        });
      }
      return null;
    }, [isSelected]);

    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(24);
    final name = desktopEntry.entries[DesktopEntryKey.name.string] ?? '';
    return Material(
      // A light tint and an outline: it marks the `Enter` target without
      // outshouting the icons, and stays distinct from the hover fill.
      color: isSelected
          ? colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: isSelected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        borderRadius: borderRadius,
        // The search field keeps the keyboard; the selection stands in for
        // the focus.
        canRequestFocus: false,
        onTap: () => onLaunch(desktopEntry, origin()),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: AspectRatio(
                  key: iconKey,
                  aspectRatio: 1,
                  child: AppIconByPath(
                    path: desktopEntry.entries[DesktopEntryKey.icon.string],
                    title: name,
                  ),
                ),
              ),
              Text.rich(
                key: labelKey,
                _highlightedName(name, matchedNameRanges(name, query)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static TextSpan _highlightedName(String name, List<TextRange> ranges) {
    if (ranges.isEmpty) {
      return TextSpan(text: name);
    }
    const bold = TextStyle(fontWeight: FontWeight.bold);
    final spans = <TextSpan>[];
    var start = 0;
    for (final range in ranges) {
      if (range.start > start) {
        spans.add(TextSpan(text: name.substring(start, range.start)));
      }
      spans.add(TextSpan(text: range.textInside(name), style: bold));
      start = range.end;
    }
    if (start < name.length) {
      spans.add(TextSpan(text: name.substring(start)));
    }
    return TextSpan(children: spans);
  }
}

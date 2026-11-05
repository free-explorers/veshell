import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/model/file_explorer_settings.dart';
import 'package:shell/file_explorer/provider/directory_item_count.dart';
import 'package:shell/file_explorer/provider/directory_listing.dart';
import 'package:shell/file_explorer/provider/file_explorer_settings.dart';
import 'package:shell/file_explorer/provider/file_explorer_state.dart';
import 'package:shell/file_explorer/provider/filtered_entry_list.dart';
import 'package:shell/file_explorer/widget/file_entry_icon.dart';
import 'package:shell/file_explorer/widget/file_sort_editor.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/overview_shortcuts.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shared/util/format_bytes.dart';
import 'package:shell/shared/widget/focus_highlight.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';

/// Height of the header holding the up button, the breadcrumb and the view
/// options.
const fileExplorerHeaderHeight = 52.0;

/// Height of one file explorer row; fixed per layout so the selection can be
/// scrolled into view by index. Rows are taller when they show details.
double fileEntryRowExtent({required bool showDetails}) =>
    showDetails ? 56.0 : 48.0;

/// The overview's Files pane: a single list of the current directory, with a
/// breadcrumb and an up action to move around.
///
/// The pane is presentational: selection and activation are handled by the
/// overview through the callbacks, so the preview slot and the keyboard
/// shortcuts share one source of truth.
class FileExplorerView extends HookConsumerWidget {
  const FileExplorerView({
    required this.searchText,
    this.selectedIndex,
    this.onSelect,
    this.onActivate,
    this.onOpenDirectory,
    this.onOpenParent,
    this.resultFocus,
    super.key,
  });

  /// Text typed in the overview search box, used as a live name filter.
  final String searchText;

  /// Index of the entry to highlight in the filtered list, or `null`.
  final int? selectedIndex;

  final ValueChanged<int>? onSelect;
  final ValueChanged<int>? onActivate;
  final ValueChanged<DirectoryPath>? onOpenDirectory;
  final VoidCallback? onOpenParent;
  final OverviewResultFocus? resultFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);
    final fileExplorer = ref.watch(fileExplorerStateProvider(screenId));
    final entryListAsync = ref.watch(filteredEntryListProvider(screenId));
    final showDetails = ref.watch(
      fileExplorerSettingsProvider.select((settings) => settings.showDetails),
    );

    useEffect(() {
      // The mutation is deferred: hooks effects run during build, and providers
      // must not be modified there.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        ref
            .read(fileExplorerStateProvider(screenId).notifier)
            .setFilterText(searchText);
      });
      return null;
    }, [searchText, screenId]);

    // Apply a pending selection left by navigating up once the listing is in.
    // The mutation is deferred: hooks effects run during build, and providers
    // must not be modified there.
    final pendingSelection = fileExplorer.pendingSelectedPath;
    final entryListValue = entryListAsync.value;
    useEffect(() {
      if (pendingSelection == null || entryListValue == null) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        final index = entryListValue.indexWhere(
          (entry) => entry.path == pendingSelection,
        );
        ref
            .read(fileExplorerStateProvider(screenId).notifier)
            .clearPendingSelection();
        if (index >= 0) {
          onSelect?.call(index);
        }
      });
      return null;
    }, [pendingSelection, entryListValue]);

    // Apply a pending "select first entry" left by descending into a directory
    // once its listing is in.
    final pendingSelectFirst = fileExplorer.pendingSelectFirst;
    useEffect(() {
      if (!pendingSelectFirst || entryListValue == null) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        ref
            .read(fileExplorerStateProvider(screenId).notifier)
            .clearPendingSelectFirst();
        if (entryListValue.isNotEmpty) {
          onSelect?.call(0);
        }
      });
      return null;
    }, [pendingSelectFirst, entryListValue]);

    // `Backspace` goes up to the parent directory (the file-manager
    // convention). It is bound inside the file pane, not above the search
    // field, so the field keeps `Backspace` for editing text.
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.backspace): ParentIntent(),
      },
      child: Actions(
        actions: {
          ParentIntent: CallbackAction<ParentIntent>(
            onInvoke: (_) {
              onOpenParent?.call();
              return null;
            },
          ),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The header is clicked, never reached by directional focus:
            // keeping it out of the focus order lets `down` from the search
            // field land on the first file instead of the breadcrumb.
            ExcludeFocus(
              child: _ExplorerHeader(
                path: fileExplorer.path,
                onOpenDirectory: onOpenDirectory,
                onOpenParent: onOpenParent,
              ),
            ),
            Expanded(
              child: entryListAsync.when(
                data: (entryList) => entryList.isEmpty
                    ? _EmptyDirectory(
                        isFiltered: fileExplorer.filterText.isNotEmpty,
                      )
                    : _FileEntryList(
                        entryList: entryList,
                        showDetails: showDetails,
                        selectedIndex: selectedIndex,
                        onSelect: onSelect,
                        onActivate: onActivate,
                        resultFocus: resultFocus,
                      ),
                error: (error, stackTrace) =>
                    _DirectoryError(path: fileExplorer.path, error: error),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The up button, the path as a breadcrumb and the view options menu.
class _ExplorerHeader extends StatelessWidget {
  const _ExplorerHeader({
    required this.path,
    this.onOpenDirectory,
    this.onOpenParent,
  });

  final DirectoryPath path;
  final ValueChanged<DirectoryPath>? onOpenDirectory;
  final VoidCallback? onOpenParent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: fileExplorerHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: context.l10n.up,
              onPressed: path.parent == null ? null : onOpenParent,
              icon: const ShellIcon(MdiIcons.arrowLeft),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _Breadcrumb(path: path, onOpenDirectory: onOpenDirectory),
            ),
            const SizedBox(width: 4),
            const _ViewOptionsButton(),
          ],
        ),
      ),
    );
  }
}

/// One clickable breadcrumb segment.
typedef _Crumb = ({String label, IconData? icon, DirectoryPath path});

/// The path as clickable segments on a rounded track.
///
/// A path inside `$HOME` starts at a "Home" crumb instead of spelling out
/// `/home/<user>`. The crumbs are laid out from the left and the view scrolls
/// to the end so the current directory stays visible when the path is too long
/// to fit.
class _Breadcrumb extends HookWidget {
  const _Breadcrumb({required this.path, this.onOpenDirectory});

  final DirectoryPath path;
  final ValueChanged<DirectoryPath>? onOpenDirectory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final crumbList = _crumbsFor(path, homeLabel: context.l10n.home);
    final scrollController = useScrollController();

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!scrollController.hasClients) {
          return;
        }
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      });
      return null;
    }, [path]);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        key: const ValueKey('file-explorer-breadcrumb'),
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < crumbList.length; i++) ...[
              if (i > 0)
                ShellIcon(
                  MdiIcons.chevronRight,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              _BreadcrumbSegment(
                crumb: crumbList[i],
                isCurrent: i == crumbList.length - 1,
                onTap: onOpenDirectory == null
                    ? null
                    : () => onOpenDirectory!(crumbList[i].path),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The breadcrumb of [path]: `Home` then the segments below `$HOME`, or every
/// segment from the root.
List<_Crumb> _crumbsFor(DirectoryPath path, {required String homeLabel}) {
  final home = Platform.environment['HOME'];
  final crumbList = path.breadcrumb;
  if (home != null && home.length > 1) {
    final homePath = DirectoryPath(home);
    final homeDepth = homePath.breadcrumb.length;
    final isUnderHome = path.path == home || path.path.startsWith('$home/');
    if (isUnderHome) {
      return [
        (label: homeLabel, icon: MdiIcons.home, path: homePath),
        for (final crumb in crumbList.skip(homeDepth))
          (label: crumb.name, icon: null, path: crumb.path),
      ];
    }
  }
  return [
    (label: '/', icon: MdiIcons.harddisk, path: const DirectoryPath('/')),
    for (final crumb in crumbList)
      (label: crumb.name, icon: null, path: crumb.path),
  ];
}

class _BreadcrumbSegment extends StatelessWidget {
  const _BreadcrumbSegment({
    required this.crumb,
    required this.isCurrent,
    this.onTap,
  });

  final _Crumb crumb;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = isCurrent ? colorScheme.onSurface : colorScheme.primary;
    final label = Text(
      crumb.label,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: isCurrent ? FontWeight.w600 : null,
        color: color,
      ),
    );
    return TextButton(
      onPressed: isCurrent ? null : onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
      ),
      child: crumb.icon == null
          ? label
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShellIcon(crumb.icon, size: 18, color: color),
                const SizedBox(width: 6),
                label,
              ],
            ),
    );
  }
}

/// The top-right menu of persisted view options: hidden files, sort order,
/// folders first and the details line.
class _ViewOptionsButton extends ConsumerWidget {
  const _ViewOptionsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(fileExplorerSettingsProvider);
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;

    void set(String path, Object value) =>
        updateFileExplorerSetting(ref, path, value);

    return MenuAnchor(
      alignmentOffset: const Offset(-180, 4),
      menuChildren: [
        CheckboxMenuButton(
          value: settings.showHidden,
          closeOnActivate: false,
          onChanged: (value) => set(fileExplorerShowHiddenPath, value ?? false),
          child: Text(l10n.showHiddenFiles),
        ),
        CheckboxMenuButton(
          value: settings.foldersFirst,
          closeOnActivate: false,
          onChanged: (value) =>
              set(fileExplorerFoldersFirstPath, value ?? false),
          child: Text(l10n.foldersFirst),
        ),
        CheckboxMenuButton(
          value: settings.showDetails,
          closeOnActivate: false,
          onChanged: (value) =>
              set(fileExplorerShowDetailsPath, value ?? false),
          child: Text(l10n.showFileDetails),
        ),
        const Divider(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(l10n.sortBy, style: textTheme.labelMedium),
        ),
        for (final key in FileSortKey.values)
          MenuItemButton(
            closeOnActivate: false,
            leadingIcon: SizedBox(
              width: 24,
              child: key == settings.sortBy
                  ? const ShellIcon(MdiIcons.check, size: 18)
                  : null,
            ),
            onPressed: () => set(fileExplorerSortByPath, key),
            child: Text(fileSortKeyLabel(l10n, key)),
          ),
        const Divider(height: 8),
        CheckboxMenuButton(
          value: settings.sortDescending,
          closeOnActivate: false,
          onChanged: (value) =>
              set(fileExplorerSortDescendingPath, value ?? false),
          child: Text(l10n.sortDescending),
        ),
      ],
      builder: (context, controller, child) => IconButton(
        tooltip: l10n.viewOptions,
        isSelected: controller.isOpen,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const ShellIcon(MdiIcons.cog),
      ),
    );
  }
}

/// The current directory's entries. One click selects, two activate.
class _FileEntryList extends HookConsumerWidget {
  const _FileEntryList({
    required this.entryList,
    required this.showDetails,
    this.selectedIndex,
    this.onSelect,
    this.onActivate,
    this.resultFocus,
  });

  final List<FileEntry> entryList;
  final bool showDetails;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;
  final ValueChanged<int>? onActivate;
  final OverviewResultFocus? resultFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final rowExtent = fileEntryRowExtent(showDetails: showDetails);
    // Select on the first tap and activate on a second tap within the
    // double-tap window. Flutter delays `onTap` by that whole window when an
    // `onDoubleTap` handler is present, which makes selection feel laggy.
    final lastTap = useRef<(int, DateTime)?>(null);

    void handleTap(int index) {
      resultFocus?.moveTo(index);
      final now = DateTime.now();
      final previous = lastTap.value;
      if (previous != null &&
          previous.$1 == index &&
          now.difference(previous.$2) < kDoubleTapTimeout) {
        lastTap.value = null;
        onActivate?.call(index);
        return;
      }
      lastTap.value = (index, now);
      onSelect?.call(index);
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final index = selectedIndex;
        if (!scrollController.hasClients || index == null || index < 0) {
          return;
        }
        final position = scrollController.position;
        final itemStart = index * rowExtent;
        final itemEnd = itemStart + rowExtent;
        if (itemStart < position.pixels) {
          scrollController.jumpTo(itemStart);
        } else if (itemEnd > position.pixels + position.viewportDimension) {
          scrollController.jumpTo(itemEnd - position.viewportDimension);
        }
      });
      return null;
    }, [selectedIndex, rowExtent]);

    // Formatting needs the locale's date symbols; computed once per build.
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();

    final focus = resultFocus;
    final list = ListView.builder(
      controller: scrollController,
      itemExtent: rowExtent,
      itemCount: entryList.length,
      itemBuilder: (context, index) {
        final entry = entryList[index];
        return _FileEntryRow(
          entry: entry,
          showDetails: showDetails,
          modifiedLabel: entry.modified == null
              ? null
              : formatModifiedDate(entry.modified!, now: now, locale: locale),
          isSelected: index == selectedIndex,
          focusNode: focus?.rowNode(index),
          onFocus: (focus == null || onSelect == null)
              ? null
              : () => onSelect!(index),
          onTap: (onSelect == null && onActivate == null)
              ? null
              : () => handleTap(index),
        );
      },
    );

    if (focus == null) {
      return list;
    }

    return Actions(
      actions: {
        NavigateIntent: CallbackAction<NavigateIntent>(
          onInvoke: (intent) {
            switch (intent.direction) {
              case NavigationDirection.up:
                final index = selectedIndex;
                if (index == null || index <= 0) {
                  focus.focusSearch();
                } else {
                  onSelect?.call(index - 1);
                  focus.moveTo(index - 1);
                }
              case NavigationDirection.down:
                final index = selectedIndex;
                final next = index == null ? 0 : index + 1;
                if (next < entryList.length) {
                  onSelect?.call(next);
                  focus.moveTo(next);
                }
              case NavigationDirection.left:
              case NavigationDirection.right:
                primaryFocus?.focusInDirection(
                  intent.direction == NavigationDirection.left
                      ? TraversalDirection.left
                      : TraversalDirection.right,
                );
            }
            return null;
          },
        ),
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onActivate?.call(selectedIndex ?? 0);
            return null;
          },
        ),
      },
      child: list,
    );
  }
}

/// When a file changed, as compact as it can be read: the time for today, the
/// day and month for this year, the full date otherwise.
String formatModifiedDate(
  DateTime modified, {
  required DateTime now,
  required String locale,
}) {
  final local = modified.toLocal();
  final DateFormat format;
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    format = DateFormat.Hm(locale);
  } else if (local.year == now.year) {
    format = DateFormat.MMMd(locale);
  } else {
    format = DateFormat.yMMMd(locale);
  }
  return format.format(local);
}

class _FileEntryRow extends StatelessWidget {
  const _FileEntryRow({
    required this.entry,
    required this.isSelected,
    this.showDetails = false,
    this.modifiedLabel,
    this.focusNode,
    this.onFocus,
    this.onTap,
  });

  final FileEntry entry;
  final bool isSelected;

  /// Whether the row shows the details line under the name.
  final bool showDetails;

  /// When the entry changed, already formatted, or `null` when unknown.
  final String? modifiedLabel;
  final FocusNode? focusNode;
  final VoidCallback? onFocus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FocusHighlight(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onFocus?.call();
        }
      },
      // The fill follows the focus, so navigating the keyboard out of the list
      // clears the last row instead of leaving it painted. Rows without a focus
      // node (no roving list) keep the selection fill.
      builder: (context, hasFocus) => _buildRow(
        context,
        highlighted: focusNode == null ? isSelected : hasFocus,
      ),
    );
  }

  Widget _buildRow(BuildContext context, {required bool highlighted}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameColor = highlighted
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    // The details line stays in the background: readable when looked for,
    // never competing with the name.
    final detailColor = highlighted
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.6)
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    final name = Text(
      entry.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: entry.isHidden ? nameColor.withValues(alpha: 0.6) : nameColor,
      ),
    );

    return Material(
      color: highlighted ? colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // The row's `Focus` node owns keyboard focus; the ink response only
        // provides the pointer affordance and its action.
        canRequestFocus: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              FileKindIcon(kind: entry.kind, isDimmed: entry.isHidden),
              const SizedBox(width: 12),
              Expanded(
                child: !showDetails
                    ? name
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          name,
                          const SizedBox(height: 2),
                          _EntryDetails(
                            entry: entry,
                            modifiedLabel: modifiedLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: detailColor,
                            ),
                          ),
                        ],
                      ),
              ),
              if (entry.isDirectory) const ShellIcon(MdiIcons.chevronRight),
            ],
          ),
        ),
      ),
    );
  }
}

/// The details line of a row: the size of a file or the item count of a
/// folder, then when it changed.
class _EntryDetails extends ConsumerWidget {
  const _EntryDetails({
    required this.entry,
    required this.modifiedLabel,
    required this.style,
  });

  final FileEntry entry;
  final String? modifiedLabel;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? what;
    if (entry.isDirectory) {
      final includeHidden = ref.watch(
        fileExplorerSettingsProvider.select((settings) => settings.showHidden),
      );
      // Unknown until counted, and left out for an unreadable folder.
      final count = ref
          .watch(directoryItemCountProvider(entry.path, includeHidden))
          .value;
      what = count == null ? null : context.l10n.folderItemCount(count);
    } else {
      what = formatBytes(context, entry.size);
    }
    final text = [?what, ?modifiedLabel].join('  ·  ');
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// Shown when the directory is empty or the filter matches nothing.
class _EmptyDirectory extends StatelessWidget {
  const _EmptyDirectory({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShellIcon(
            isFiltered
                ? MdiIcons.fileSearchOutline
                : MdiIcons.folderOpenOutline,
            size: 48,
            color: color.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            isFiltered
                ? context.l10n.noMatchingItems
                : context.l10n.folderEmpty,
            style: theme.textTheme.bodyLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Shown when the directory cannot be listed, with a retry.
class _DirectoryError extends HookConsumerWidget {
  const _DirectoryError({required this.path, required this.error});

  final DirectoryPath path;
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShellIcon(
              MdiIcons.folderAlertOutline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.cannotOpenPath(path.path),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.invalidate(directoryListingProvider(path)),
              icon: const ShellIcon(MdiIcons.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

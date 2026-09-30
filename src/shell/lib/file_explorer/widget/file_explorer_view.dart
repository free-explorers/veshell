import 'package:flutter/gestures.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/provider/directory_listing.dart';
import 'package:shell/file_explorer/provider/file_explorer_state.dart';
import 'package:shell/file_explorer/provider/filtered_entry_list.dart';
import 'package:shell/file_explorer/widget/file_entry_icon.dart';
import 'package:shell/screen/widget/current_screen_id.dart';

/// Height of one file explorer row; fixed so the selection can be scrolled into
/// view by index.
const fileEntryRowHeight = 48.0;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);
    final fileExplorer = ref.watch(fileExplorerStateProvider(screenId));
    final entryListAsync = ref.watch(filteredEntryListProvider(screenId));

    useEffect(() {
      ref
          .read(fileExplorerStateProvider(screenId).notifier)
          .setFilterText(searchText);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BreadcrumbBar(
          path: fileExplorer.path,
          onOpenDirectory: onOpenDirectory,
          onOpenParent: onOpenParent,
        ),
        const Divider(height: 1),
        Expanded(
          child: entryListAsync.when(
            data: (entryList) => entryList.isEmpty
                ? _EmptyDirectory(
                    isFiltered: fileExplorer.filterText.isNotEmpty,
                  )
                : _FileEntryList(
                    entryList: entryList,
                    selectedIndex: selectedIndex,
                    onSelect: onSelect,
                    onActivate: onActivate,
                  ),
            error: (error, stackTrace) =>
                _DirectoryError(path: fileExplorer.path, error: error),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

/// Up action and the path as a clickable breadcrumb.
///
/// The crumbs are laid out from the left, next to the up button, and the view
/// scrolls to the end so the current directory stays visible when the path is
/// too long to fit.
class _BreadcrumbBar extends HookWidget {
  const _BreadcrumbBar({
    required this.path,
    this.onOpenDirectory,
    this.onOpenParent,
  });

  final DirectoryPath path;
  final ValueChanged<DirectoryPath>? onOpenDirectory;
  final VoidCallback? onOpenParent;

  @override
  Widget build(BuildContext context) {
    final crumbList = path.breadcrumb;
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

    return SizedBox(
      height: fileEntryRowHeight,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Up',
            onPressed: path.parent == null ? null : onOpenParent,
            icon: const Icon(MdiIcons.arrowLeft),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('file-explorer-breadcrumb'),
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (crumbList.isEmpty)
                    const _BreadcrumbSegment(label: '/', isCurrent: true)
                  else
                    for (var i = 0; i < crumbList.length; i++) ...[
                      if (i > 0) const Icon(MdiIcons.chevronRight, size: 18),
                      _BreadcrumbSegment(
                        label: crumbList[i].name,
                        isCurrent: i == crumbList.length - 1,
                        onTap: onOpenDirectory == null
                            ? null
                            : () => onOpenDirectory!(crumbList[i].path),
                      ),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreadcrumbSegment extends StatelessWidget {
  const _BreadcrumbSegment({
    required this.label,
    required this.isCurrent,
    this.onTap,
  });

  final String label;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: isCurrent ? null : onTap,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: theme.colorScheme.primary,
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isCurrent ? FontWeight.w600 : null,
          color: isCurrent ? theme.colorScheme.onSurface : null,
        ),
      ),
    );
  }
}

/// The current directory's entries. One click selects, two activate.
class _FileEntryList extends HookConsumerWidget {
  const _FileEntryList({
    required this.entryList,
    this.selectedIndex,
    this.onSelect,
    this.onActivate,
  });

  final List<FileEntry> entryList;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;
  final ValueChanged<int>? onActivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    // Select on the first tap and activate on a second tap within the
    // double-tap window. Flutter delays `onTap` by that whole window when an
    // `onDoubleTap` handler is present, which makes selection feel laggy.
    final lastTap = useRef<(int, DateTime)?>(null);

    void handleTap(int index) {
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
        final itemStart = index * fileEntryRowHeight;
        final itemEnd = itemStart + fileEntryRowHeight;
        if (itemStart < position.pixels) {
          scrollController.jumpTo(itemStart);
        } else if (itemEnd > position.pixels + position.viewportDimension) {
          scrollController.jumpTo(itemEnd - position.viewportDimension);
        }
      });
      return null;
    }, [selectedIndex]);

    return ListView.builder(
      controller: scrollController,
      itemExtent: fileEntryRowHeight,
      itemCount: entryList.length,
      itemBuilder: (context, index) {
        final entry = entryList[index];
        return _FileEntryRow(
          entry: entry,
          isSelected: index == selectedIndex,
          onTap: (onSelect == null && onActivate == null)
              ? null
              : () => handleTap(index),
        );
      },
    );
  }
}

class _FileEntryRow extends StatelessWidget {
  const _FileEntryRow({
    required this.entry,
    required this.isSelected,
    this.onTap,
  });

  final FileEntry entry;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(iconForFileEntry(entry)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entry.isDirectory) const Icon(MdiIcons.chevronRight),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the directory is empty or the filter matches nothing.
class _EmptyDirectory extends StatelessWidget {
  const _EmptyDirectory({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        isFiltered ? 'No matching items' : 'This folder is empty',
        style: Theme.of(context).textTheme.bodyLarge,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(MdiIcons.folderAlertOutline, size: 48),
            const SizedBox(height: 12),
            Text(
              'Cannot open ${path.path}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.invalidate(directoryListingProvider(path)),
              icon: const Icon(MdiIcons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

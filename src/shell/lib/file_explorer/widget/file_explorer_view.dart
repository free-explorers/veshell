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
    this.selectedPath,
    this.onSelect,
    this.onActivate,
    this.onOpenDirectory,
    this.onOpenParent,
    super.key,
  });

  /// Text typed in the overview search box, used as a live name filter.
  final String searchText;

  /// The entry to highlight, or `null`.
  final DirectoryPath? selectedPath;

  final ValueChanged<FileEntry>? onSelect;
  final ValueChanged<FileEntry>? onActivate;
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
                    selectedPath: selectedPath,
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

/// Up action and the cumulative path segments, each a shortcut to an ancestor.
class _BreadcrumbBar extends StatelessWidget {
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
    final breadcrumbOnlyList = path.breadcrumb;
    return SizedBox(
      height: fileEntryRowHeight,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Up',
            onPressed: path.parent == null ? null : onOpenParent,
            icon: const Icon(MdiIcons.arrowUp),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  for (final segment in breadcrumbOnlyList)
                    TextButton(
                      onPressed: onOpenDirectory == null
                          ? null
                          : () => onOpenDirectory!(segment.path),
                      child: Text(segment.name),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The current directory's entries. One click selects, two activate.
class _FileEntryList extends HookConsumerWidget {
  const _FileEntryList({
    required this.entryList,
    this.selectedPath,
    this.onSelect,
    this.onActivate,
  });

  final List<FileEntry> entryList;
  final DirectoryPath? selectedPath;
  final ValueChanged<FileEntry>? onSelect;
  final ValueChanged<FileEntry>? onActivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final selectedIndex = entryList.indexWhere(
      (entry) => entry.path == selectedPath,
    );

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!scrollController.hasClients || selectedIndex < 0) {
          return;
        }
        final position = scrollController.position;
        final itemStart = selectedIndex * fileEntryRowHeight;
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
          isSelected: entry.path == selectedPath,
          onTap: onSelect == null ? null : () => onSelect!(entry),
          onDoubleTap: onActivate == null ? null : () => onActivate!(entry),
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
    this.onDoubleTap,
  });

  final FileEntry entry;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
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

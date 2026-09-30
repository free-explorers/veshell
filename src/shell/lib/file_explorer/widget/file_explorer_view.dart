import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/provider/directory_listing.dart';
import 'package:shell/file_explorer/provider/file_explorer_state.dart';
import 'package:shell/file_explorer/provider/file_opener.dart';
import 'package:shell/file_explorer/provider/filtered_entry_list.dart';
import 'package:shell/file_explorer/widget/file_entry_icon.dart';
import 'package:shell/screen/widget/current_screen_id.dart';

/// The overview's Files pane: a single list of the current directory, with a
/// breadcrumb and an up action to move around.
class FileExplorerView extends HookConsumerWidget {
  const FileExplorerView({
    required this.searchText,
    this.onFileOpened,
    super.key,
  });

  /// Text typed in the overview search box, used as a live name filter.
  final String searchText;

  /// Called after a file was handed to its default handler.
  final VoidCallback? onFileOpened;

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
        _BreadcrumbBar(path: fileExplorer.path),
        const Divider(height: 1),
        Expanded(
          child: entryListAsync.when(
            data: (entryList) => entryList.isEmpty
                ? _EmptyDirectory(
                    isFiltered: fileExplorer.filterText.isNotEmpty,
                  )
                : _FileEntryList(
                    entryList: entryList,
                    onFileOpened: onFileOpened,
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
class _BreadcrumbBar extends HookConsumerWidget {
  const _BreadcrumbBar({required this.path});

  final DirectoryPath path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);
    final breadcrumbOnlyList = path.breadcrumb;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Up',
            onPressed: path.parent == null
                ? null
                : () => ref
                      .read(fileExplorerStateProvider(screenId).notifier)
                      .openParentDirectory(),
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
                      onPressed: () => ref
                          .read(fileExplorerStateProvider(screenId).notifier)
                          .openDirectory(segment.path),
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

/// The current directory's entries. Directories navigate; files open with the
/// default handler.
class _FileEntryList extends HookConsumerWidget {
  const _FileEntryList({required this.entryList, this.onFileOpened});

  final List<FileEntry> entryList;
  final VoidCallback? onFileOpened;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);
    return ListView.builder(
      itemCount: entryList.length,
      itemBuilder: (context, index) {
        final entry = entryList[index];
        return ListTile(
          leading: Icon(iconForFileEntry(entry)),
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: entry.isDirectory
              ? const Icon(MdiIcons.chevronRight)
              : null,
          onTap: () => unawaited(
            _openEntry(ref, screenId, entry, onFileOpened: onFileOpened),
          ),
        );
      },
    );
  }
}

/// Opens [entry]: a directory navigates, a file goes to the default handler and
/// then notifies the caller so it can dismiss the overview.
Future<void> _openEntry(
  WidgetRef ref,
  String screenId,
  FileEntry entry, {
  required VoidCallback? onFileOpened,
}) async {
  if (entry.isDirectory) {
    ref
        .read(fileExplorerStateProvider(screenId).notifier)
        .openDirectory(entry.path);
    return;
  }
  final didOpen = await ref
      .read(fileOpenerProvider.notifier)
      .openFile(entry.path);
  if (didOpen) {
    onFileOpened?.call();
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

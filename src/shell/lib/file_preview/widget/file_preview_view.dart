import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_preview/model/file_preview.dart';
import 'package:shell/file_preview/provider/file_preview.dart';
import 'package:shell/theme/provider/theme.dart';

/// Renders the preview of [path] in the overview's content slot.
class FilePreviewView extends ConsumerWidget {
  const FilePreviewView({required this.path, super.key});

  final DirectoryPath path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(filePreviewProvider(path));
    return Material(
      borderRadius: BorderRadius.circular(surfaceRadius),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surface,
      child: previewAsync.when(
        data: (preview) => switch (preview) {
          TextFilePreview(:final content, :final isTruncated) => _TextPreview(
            content: content,
            isTruncated: isTruncated,
          ),
          ImageFilePreview(:final path) => _ImagePreview(path: path),
          SvgFilePreview(:final path) => _SvgPreview(path: path),
          BinaryFilePreview(:final hexDump, :final size) => _BinaryPreview(
            hexDump: hexDump,
            size: size,
          ),
          MetadataFilePreview(:final name, :final size, :final modified) =>
            _MetadataPreview(name: name, size: size, modified: modified),
          DirectoryFilePreview(:final name, :final entryCount) =>
            _DirectoryPreview(name: name, entryCount: entryCount),
          ErrorFilePreview(:final message) => _MessagePreview(
            icon: MdiIcons.alertCircleOutline,
            message: message,
          ),
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _MessagePreview(
          icon: MdiIcons.alertCircleOutline,
          message: '$error',
        ),
      ),
    );
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.content, required this.isTruncated});

  final String content;
  final bool isTruncated;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isTruncated)
          const _InfoBar(label: 'Preview truncated to the first 256 KiB'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _MessagePreview(
            icon: MdiIcons.imageBrokenVariant,
            message: 'Cannot decode ${p.basename(path)}',
          ),
        ),
      ),
    );
  }
}

class _SvgPreview extends StatelessWidget {
  const _SvgPreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(child: SvgPicture.file(File(path))),
    );
  }
}

class _BinaryPreview extends StatelessWidget {
  const _BinaryPreview({required this.hexDump, required this.size});

  final String hexDump;
  final int size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoBar(label: 'Binary · ${_formatBytes(size)}'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              hexDump,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataPreview extends StatelessWidget {
  const _MetadataPreview({
    required this.name,
    required this.size,
    required this.modified,
  });

  final String name;
  final int size;
  final DateTime modified;

  @override
  Widget build(BuildContext context) {
    return _NoPreview(
      icon: MdiIcons.fileOutline,
      title: name,
      lines: [
        _formatBytes(size),
        'Modified ${_formatModified(modified)}',
        'No inline preview for this type',
      ],
    );
  }
}

class _DirectoryPreview extends StatelessWidget {
  const _DirectoryPreview({required this.name, required this.entryCount});

  final String name;
  final int entryCount;

  @override
  Widget build(BuildContext context) {
    return _NoPreview(
      icon: MdiIcons.folderOutline,
      title: name,
      lines: [
        if (entryCount >= 1000) '1000+ items' else '$entryCount items',
        'Double click or Super+D to open',
      ],
    );
  }
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _NoPreview(icon: icon, title: message, lines: const []);
  }
}

class _NoPreview extends StatelessWidget {
  const _NoPreview({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            for (final line in lines) ...[
              const SizedBox(height: 4),
              Text(
                line,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  const _InfoBar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(label, style: theme.textTheme.labelMedium),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final digits = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unitIndex]}';
}

String _formatModified(DateTime modified) =>
    modified.toLocal().toString().split('.').first;

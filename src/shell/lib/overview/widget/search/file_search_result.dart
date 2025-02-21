import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// List of applications for the given searchText
class FileSearchResult extends HookConsumerWidget {
  ///
  const FileSearchResult({required this.searchText, super.key});
  final String searchText;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      children: [
        SizedBox(
          height: 16,
        ),
        Text('Work in progress'),
      ],
    );
  }
}

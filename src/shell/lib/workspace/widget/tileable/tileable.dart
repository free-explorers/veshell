import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// a Tileable is an element that is displayed inside a Workspace considered
/// by the layout typically an application window or the application launcher
abstract class Tileable extends HookConsumerWidget {
  /// Abstract class for a Tileable
  const Tileable({required this.isSelected, this.onGrabFocus, super.key});

  /// Indicates if the tileable is the selected of the workspace
  final bool isSelected;

  final VoidCallback? onGrabFocus;

  /// Builder to return widget for the workpace panel
  Widget buildPanelWidget(
    BuildContext context,
    WidgetRef ref,
  );

  List<Widget> buildMenuChildren(
    BuildContext context,
    WidgetRef ref,
  );
}

import 'package:flutter/material.dart';

/// InheritedWidget to provide a Workspace ID throughout the widget tree
class CurrentWorkspaceId extends InheritedWidget {
  /// Creates a WorkspaceIdProvider with the given Workspace ID.
  const CurrentWorkspaceId({
    required this.workspaceId,
    required super.child,
    super.key,
  });

  /// The Workspace ID being provided to descendant widgets.
  final String workspaceId;

  /// Gets the Workspace ID from the nearest workspaceIdProvider ancestor.
  static String of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<CurrentWorkspaceId>();
    if (provider == null) {
      throw FlutterError('workspaceIdProvider not found in the widget tree');
    }
    return provider.workspaceId;
  }

  @override
  bool updateShouldNotify(CurrentWorkspaceId oldWidget) =>
      workspaceId != oldWidget.workspaceId;
}

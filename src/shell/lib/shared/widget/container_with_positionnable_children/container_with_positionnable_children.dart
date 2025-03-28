import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ContainerWithPositionnableChildren extends HookConsumerWidget {
  const ContainerWithPositionnableChildren({
    required this.children,
    super.key,
  });

  final List<Widget> children;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dragUpdateController = useMemoized(DragUpdateController.new);
    final dragEndController = useMemoized(DragEndController.new);
    return LayoutBuilder(
      builder: (context, constraints) {
        return RepositionnableControllerWidget(
          dragUpdateController: dragUpdateController,
          dragEndController: dragEndController,
          constraints: constraints,
          child: GestureDetector(
            onPanUpdate: (details) => dragUpdateController.value = details,
            onPanEnd: (details) => dragEndController.value = details,
            child: Material(
              child: Stack(
                alignment: Alignment.center,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}

class RepositionableResizeableWidget extends HookConsumerWidget {
  const RepositionableResizeableWidget({
    required this.child,
    super.key,
    this.origin = Rect.zero,
  });

  final Rect origin;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned.fromRect(
      rect: origin,
      child: Column(
        children: [
          ColoredBox(color: Colors.red, child: child),
        ],
      ),
    );
  }
}

class RepositionnableControllerWidget extends InheritedWidget {
  const RepositionnableControllerWidget({
    required this.dragUpdateController,
    required this.dragEndController,
    required this.constraints,
    required super.child,
    super.key,
  });

  final DragUpdateController dragUpdateController;
  final DragEndController dragEndController;
  final BoxConstraints constraints;

  static RepositionnableControllerWidget of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<RepositionnableControllerWidget>();
    assert(result != null, 'No ConstraintsInheritedWidget found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(RepositionnableControllerWidget oldWidget) {
    return dragUpdateController != oldWidget.dragUpdateController ||
        dragEndController != oldWidget.dragEndController ||
        constraints != oldWidget.constraints;
  }
}

class DragUpdateController extends ValueNotifier<DragUpdateDetails> {
  DragUpdateController()
      : super(DragUpdateDetails(globalPosition: Offset.zero));
}

class DragEndController extends ValueNotifier<DragEndDetails> {
  DragEndController() : super(DragEndDetails());
}

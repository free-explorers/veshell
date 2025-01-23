import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _expandedEnlargePadding = 12.0;

typedef ExpandableBuilder = Widget Function(
  BuildContext context, {
  required bool isExpanded,
});

class ExpandableContainer extends StatefulWidget {
  const ExpandableContainer({
    required this.builder,
    super.key,
  });

  final ExpandableBuilder builder;
  @override
  State<ExpandableContainer> createState() => ExpandableContainerState();

  static ExpandableContainerState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ExpandableContainerScope>();
    assert(() {
      if (scope == null) {
        throw FlutterError(
          'No ExpandableContainer found in context',
        );
      }
      return true;
    }());
    return scope!.expandableContainerState;
  }
}

class ExpandableContainerState extends State<ExpandableContainer> {
  bool isExpanded = false;
  final String uuid = const Uuid().v4();
  late PageRouteBuilder<LayoutBuilder>? _expandedRoute;
  @override
  Widget build(BuildContext context) {
    return buildHeroContainer(context, isExpanded: false);
  }

  Widget buildHeroContainer(BuildContext context, {required bool isExpanded}) {
    return Hero(
      tag: uuid,
      child: _ExpandableContainerScope(
        expandableContainerState: this,
        child: Builder(
          builder: (context) {
            return widget.builder(context, isExpanded: isExpanded);
          },
        ),
      ),
    );
  }

  void expand() {
    if (isExpanded) return;
    final currentBox = context.findRenderObject()! as RenderBox;
    final currentCoordinates = currentBox.localToGlobal(
      Offset.zero,
    );

    _expandedRoute = PageRouteBuilder<LayoutBuilder>(
      opaque: false,
      barrierColor: Colors.black38,
      barrierDismissible: true,
      pageBuilder: (BuildContext context, _, __) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned(
                  top: currentCoordinates.dy - _expandedEnlargePadding,
                  left: currentCoordinates.dx - _expandedEnlargePadding,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight:
                          constraints.biggest.height - currentCoordinates.dy,
                    ),
                    width: currentBox.size.width + _expandedEnlargePadding * 2,
                    child: buildHeroContainer(context, isExpanded: true),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    _expandedRoute!.popped.then((_) {
      setState(() {
        isExpanded = false;
      });
    });
    Navigator.of(context).push(
      _expandedRoute!,
    );
    setState(() {
      isExpanded = true;
    });
  }

  void collapse() {
    if (!isExpanded) return;
    setState(() {
      isExpanded = false;
      Navigator.of(context).pop();
    });
  }

  void toggle() {
    if (isExpanded) {
      collapse();
    } else {
      expand();
    }
  }
}

class _ExpandableContainerScope extends InheritedWidget {
  const _ExpandableContainerScope({
    required this.expandableContainerState,
    required super.child,
  });
  final ExpandableContainerState expandableContainerState;
  @override
  bool updateShouldNotify(_ExpandableContainerScope oldWidget) {
    return expandableContainerState != oldWidget.expandableContainerState;
  }
}

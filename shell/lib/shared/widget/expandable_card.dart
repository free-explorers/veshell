import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _expandedElevation = 1.0;
const _expandedShadowPadding = 64.0;
const _expandedEnlargePadding = 12.0;

typedef ExpandableBuilder = Widget Function(
  BuildContext context,
  bool isExpanded,
);

class ExpandableCard extends StatefulWidget {
  const ExpandableCard({
    required this.builder,
    super.key,
  });

  final ExpandableBuilder builder;
  @override
  State<ExpandableCard> createState() => ExpandableCardState();

  static ExpandableCardState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ExpandableCardScope>();
    assert(() {
      if (scope == null) {
        throw FlutterError(
          'No ExpandableCard found in context',
        );
      }
      return true;
    }());
    return scope!.expandableCardState;
  }
}

class ExpandableCardState extends State<ExpandableCard> {
  bool isExpanded = false;
  final String uuid = const Uuid().v4();
  late PageRouteBuilder<LayoutBuilder>? _expandedRoute;
  @override
  Widget build(BuildContext context) {
    return buildHeroCard(context, isExpanded: false);
  }

  Widget buildHeroCard(BuildContext context, {required bool isExpanded}) {
    return Hero(
      tag: uuid,
      child: _ExpandableCardScope(
        expandableCardState: this,
        child: Card(
          elevation: isExpanded ? _expandedElevation : 0,
          surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
          clipBehavior: Clip.antiAlias,
          child: Builder(
            builder: (context) {
              return widget.builder(context, isExpanded);
            },
          ),
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
                    child: buildHeroCard(context, isExpanded: true),
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

class _ExpandableCardScope extends InheritedWidget {
  const _ExpandableCardScope({
    required this.expandableCardState,
    required super.child,
  });
  final ExpandableCardState expandableCardState;
  @override
  bool updateShouldNotify(_ExpandableCardScope oldWidget) {
    return expandableCardState != oldWidget.expandableCardState;
  }
}

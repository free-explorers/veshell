import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

const _expandedEnlargePadding = 12.0;

/// The room the expanded container keeps from the screen's edges.
const _screenMargin = 12.0;

typedef ExpandableBuilder =
    Widget Function(BuildContext context, {required bool isExpanded});

class ExpandableContainer extends StatefulWidget {
  const ExpandableContainer({required this.builder, super.key});

  final ExpandableBuilder builder;
  @override
  State<ExpandableContainer> createState() => ExpandableContainerState();

  static ExpandableContainerState of(BuildContext context) {
    final state = maybeOf(context);
    assert(() {
      if (state == null) {
        throw FlutterError('No ExpandableContainer found in context');
      }
      return true;
    }());
    return state!;
  }

  static ExpandableContainerState? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ExpandableContainerScope>()
      ?.expandableContainerState;
}

class ExpandableContainerState extends State<ExpandableContainer> {
  bool isExpanded = false;
  final String uuid = const Uuid().v4();
  PageRouteBuilder<void>? _expandedRoute;

  @override
  void dispose() {
    final route = _expandedRoute;
    _expandedRoute = null;
    // Removing a route during the owner's teardown can mutate the Navigator
    // while it is building. Close only our orphaned popup after this frame.
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = route.navigator;
        if (navigator != null && navigator.mounted && route.isActive) {
          navigator.removeRoute(route);
        }
      });
    }
    super.dispose();
  }

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
    if (!mounted || isExpanded) return;
    final currentBox = context.findRenderObject()! as RenderBox;
    final currentCoordinates = currentBox.localToGlobal(Offset.zero);

    final route = PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black38,
      barrierDismissible: true,
      pageBuilder: (context, _, _) {
        if (!mounted) return const SizedBox.shrink();
        return CustomSingleChildLayout(
          delegate: _ExpandedLayoutDelegate(
            anchor:
                currentCoordinates -
                const Offset(_expandedEnlargePadding, _expandedEnlargePadding),
            width: currentBox.size.width + _expandedEnlargePadding * 2,
          ),
          child: buildHeroContainer(context, isExpanded: true),
        );
      },
    );
    _expandedRoute = route;
    route.popped.then((_) {
      if (!mounted || _expandedRoute != route) return;
      setState(() {
        _expandedRoute = null;
        isExpanded = false;
      });
    });
    Navigator.of(context).push(route);
    setState(() {
      isExpanded = true;
    });
  }

  void collapse() {
    if (!mounted || !isExpanded) return;
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

/// Places the expanded container over the collapsed one, as tall as its
/// content within the screen's margins, and raised just enough to fit when
/// the collapsed one sits too low for it.
class _ExpandedLayoutDelegate extends SingleChildLayoutDelegate {
  const _ExpandedLayoutDelegate({required this.anchor, required this.width});

  /// Where the expanded container would start: over the collapsed one.
  final Offset anchor;
  final double width;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = max(0, constraints.maxWidth - _screenMargin * 2);
    return BoxConstraints(
      maxWidth: min(width, maxWidth.toDouble()),
      minWidth: min(width, maxWidth.toDouble()),
      maxHeight: max(0, constraints.maxHeight - _screenMargin * 2),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double fit(double start, double extent, double available) =>
        max(_screenMargin, min(start, available - _screenMargin - extent));
    return Offset(
      fit(anchor.dx, childSize.width, size.width),
      fit(anchor.dy, childSize.height, size.height),
    );
  }

  @override
  bool shouldRelayout(_ExpandedLayoutDelegate oldDelegate) =>
      anchor != oldDelegate.anchor || width != oldDelegate.width;
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

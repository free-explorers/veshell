import 'package:material_ui/material_ui.dart';

/// A [Focus] wrapper that rebuilds its child when the node gains or loses
/// focus, so the child can paint a focus effect that disappears as soon as the
/// keyboard leaves it.
///
/// Used by the roving list rows: the highlight follows the focus, so navigating
/// focus out of the list (for example to the content pane) clears the highlight
/// instead of leaving the last selected row painted.
class FocusHighlight extends StatefulWidget {
  const FocusHighlight({
    required this.focusNode,
    required this.builder,
    this.onFocusChange,
    super.key,
  });

  /// The node to watch and to give to the [Focus] widget. When `null`, the
  /// builder is called with `false` and no focus is installed.
  final FocusNode? focusNode;

  /// Builds the content, told whether the node currently holds focus.
  final Widget Function(BuildContext context, bool hasFocus) builder;

  /// Forwarded to the [Focus] widget's `onFocusChange`.
  final ValueChanged<bool>? onFocusChange;

  @override
  State<FocusHighlight> createState() => _FocusHighlightState();
}

class _FocusHighlightState extends State<FocusHighlight> {
  FocusNode? _node;

  @override
  void initState() {
    super.initState();
    _attach(widget.focusNode);
  }

  @override
  void didUpdateWidget(FocusHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _attach(widget.focusNode);
    }
  }

  void _attach(FocusNode? node) {
    _node?.removeListener(_handleFocusChanged);
    _node = node;
    _node?.addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _node?.removeListener(_handleFocusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.focusNode;
    if (node == null) {
      return widget.builder(context, false);
    }
    return Focus(
      focusNode: node,
      onFocusChange: widget.onFocusChange,
      child: widget.builder(context, node.hasFocus),
    );
  }
}

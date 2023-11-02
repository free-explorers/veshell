import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/common/state/xdg_toplevel_state.dart';
import 'package:zenith/ui/desktop/decorations/client_side_decorations.dart';
import 'package:zenith/ui/desktop/decorations/server_side_decorations.dart';

class WithDecorations extends ConsumerWidget {
  final int viewId;
  final Widget child;

  const WithDecorations({
    super.key,
    required this.viewId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var decoration = ref.watch(xdgToplevelStatesProvider(viewId).select((v) => v.decoration));
    switch (decoration) {
      case ToplevelDecoration.none:
      case ToplevelDecoration.clientSide:
        return ClientSideDecorations(
          viewId: viewId,
          child: child,
        );
      case ToplevelDecoration.serverSide:
        return ServerSideDecorations(
          viewId: viewId,
          child: child,
        );
    }
  }
}

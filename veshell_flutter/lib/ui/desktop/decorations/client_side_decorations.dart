import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/common/state/xdg_surface_state.dart';
import 'package:zenith/ui/desktop/activate_and_raise.dart';
import 'package:zenith/ui/desktop/contain_to_input_region.dart';

class ClientSideDecorations extends StatelessWidget {
  final int viewId;
  final Widget child;

  const ClientSideDecorations({
    super.key,
    required this.viewId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ActivateAndRaise(
      viewId: viewId,
      child: ContainToInputRegion(
        viewId: viewId,
        child: child,
      ),
    );
  }
}

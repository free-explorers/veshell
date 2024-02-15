import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/screen/widget/workspace_list.dart';

class ScreenPanel extends HookConsumerWidget implements PreferredSizeWidget {
  const ScreenPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      textStyle: TextStyle(color: theme.colorScheme.onSurface),
      child: SizedBox(
        width: 48,
        child: Column(
          children: [
            IconButton.filled(
              style: ButtonStyle(
                shape: MaterialStateProperty.all(
                  const RoundedRectangleBorder(),
                ),
              ),
              onPressed: () {},
              icon: SvgPicture.asset('assets/ship_vector.svg', width: 30),
            ),
            const Expanded(child: WorkspaceListView()),
          ],
        ),
      ),
    );
  }

  @override
  // TODO: implement preferredSize to expand height
  Size get preferredSize => const Size.fromWidth(48);
}

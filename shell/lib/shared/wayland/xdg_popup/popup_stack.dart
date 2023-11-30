import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/wayland/xdg_popup/xdg_popup.provider.dart';

class PopupStack extends ConsumerWidget {
  const PopupStack({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      key: ref.watch(popupStackGlobalKeyProvider),
      children: [
        for (int surfaceId in ref.watch(popupStackChildrenProvider))
          ref.watch(popupWidgetProvider(surfaceId)),
      ],
    );
  }
}

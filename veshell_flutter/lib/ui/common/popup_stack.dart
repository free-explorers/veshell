import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/common/state/xdg_popup_state.dart';

part '../../generated/ui/common/popup_stack.g.dart';

class PopupStack extends ConsumerWidget {
  const PopupStack({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      key: ref.watch(popupStackGlobalKeyProvider),
      children: [
        for (int viewId in ref.watch(popupStackChildrenProvider)) ref.watch(popupWidgetProvider(viewId)),
      ],
    );
  }
}

@Riverpod(keepAlive: true)
GlobalKey popupStackGlobalKey(PopupStackGlobalKeyRef ref) => GlobalKey();

@Riverpod(keepAlive: true)
class PopupStackChildren extends _$PopupStackChildren {
  @override
  IList<int> build() {
    return IList();
  }

  void add(int viewId) => state = state.add(viewId);

  void remove(int viewId) => state = state.remove(viewId);
}

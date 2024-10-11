import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/model/wifi_access_point.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/provider/single_expanded_state.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/provider/wifi_access_point_list.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/provider/wifi_manager.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/widget/access_point_icon.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/widget/access_point_label.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';
import 'package:shell/shared/widget/expandable.dart';
import 'package:shell/shared/widget/expandable_card.dart';

class AvailableAccessPointList extends HookConsumerWidget {
  const AvailableAccessPointList({
    required this.address,
    super.key,
  });

  final String address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(nmDeviceProvider(address));

    final availableAccessPoint = ref
        .watch(wifiAccessPointListProvider(address))
        .where(
          (element) => element.settingsConnection == null,
        )
        .toList();
    return Flexible(
      child: ColoredBox(
        color: Colors.black12,
        child: ListView.builder(
          shrinkWrap: true,
          itemBuilder: (context, index) {
            final accessPoint = availableAccessPoint.elementAt(index);
            return AvailableAccessPointTile(
              accessPoint: accessPoint,
              address: address,
            );
          },
          itemCount: availableAccessPoint.length,
        ),
      ),
    );
  }
}

class AvailableAccessPointTile extends HookConsumerWidget {
  const AvailableAccessPointTile({
    required this.accessPoint,
    required this.address,
    super.key,
  });

  final WifiAccessPoint accessPoint;
  final String address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded =
        ref.watch(singleExpandedProvider('AvailableAccessPointTile')) ==
            accessPoint.ssid;

    final textController = useTextEditingController();
    final tile = ListTile(
      leading: AccessPointIcon(
        accessPoint: accessPoint.bestAccessPoint!,
      ),
      title: AccessPointLabel(
        accessPoint: accessPoint.bestAccessPoint!,
      ),
      trailing: Icon(MdiIcons.plus),
      onTap: () {
        ref
            .read(singleExpandedProvider('AvailableAccessPointTile').notifier)
            .toggleMe(accessPoint.ssid);
      },
    );

    Future<void> onSubmitted() async {
      final res = await ref
          .read(wifiManagerProvider(address).notifier)
          .connectToAccessPoint(
            accessPoint.bestAccessPoint!,
            textController.text,
          );
      ExpandableCard.of(context).collapse();
    }

    return Expandable(
      isExpanded: isExpanded,
      collapsed: tile,
      expanded: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tile,
          ColoredBox(
            color: Colors.black12,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onSubmitted: (_) => onSubmitted(),
                      controller: textController,
                      decoration: const InputDecoration(
                        hintText: 'Password',
                      ),
                      obscureText: true,
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  IconButton(
                    onPressed: onSubmitted,
                    icon: Icon(MdiIcons.wifiPlus),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

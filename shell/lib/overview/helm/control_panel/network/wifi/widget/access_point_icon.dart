import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:nm/nm.dart';

class AccessPointIcon extends StatelessWidget {
  const AccessPointIcon({
    required this.accessPoint,
    this.color,
    super.key,
  });

  final NetworkManagerAccessPoint accessPoint;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isLock =
        accessPoint.flags.contains(NetworkManagerWifiAccessPointFlag.privacy);
    return Icon(
      switch (accessPoint.strength) {
        < 20 => isLock ? MdiIcons.wifiStrength1Lock : MdiIcons.wifiStrength1,
        < 40 => isLock ? MdiIcons.wifiStrength2Lock : MdiIcons.wifiStrength2,
        < 60 => isLock ? MdiIcons.wifiStrength3Lock : MdiIcons.wifiStrength3,
        < 80 => isLock ? MdiIcons.wifiStrength4Lock : MdiIcons.wifiStrength4,
        _ => isLock ? MdiIcons.wifiStrength4Lock : MdiIcons.wifiStrength4,
      },
      color: color,
    );
  }
}

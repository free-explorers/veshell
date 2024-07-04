import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class NotificationPanel extends StatelessWidget {
  const NotificationPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          leading: Icon(MdiIcons.bell),
                          title: const Text('Notification title'),
                          subtitle: const Text('Notification body'),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: Icon(MdiIcons.bell),
                          title: const Text('Notification title'),
                          subtitle: const Text('Notification body'),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: Icon(MdiIcons.bell),
                          title: const Text('Notification title'),
                          subtitle: const Text('Notification body'),
                          onTap: () {},
                        ),
                      ],
                    ),
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

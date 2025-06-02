import 'dart:io';
import 'dart:typed_data';

import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/notification/model/notification.serializable.dart' as Me;

class NotificationWidget extends StatelessWidget {
  const NotificationWidget({
    required this.notification,
    this.onClose,
    super.key,
  });

  final Me.Notification notification;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (notification.appId != null)
                    SizedBox.square(
                      dimension: 16,
                      child: AppIconById(id: notification.appId),
                    )
                  else if (File(
                    Uri.parse(notification.dbusNotification.appIcon)
                        .toFilePath(),
                  ).existsSync())
                    SizedBox.square(
                      dimension: 16,
                      child: Image.file(
                        File(
                          Uri.parse(notification.dbusNotification.appIcon)
                              .toFilePath(),
                        ),
                      ),
                    )
                  else
                    const Icon(MdiIcons.bell, size: 16),
                  const SizedBox(
                    width: 8,
                  ),
                  Text.rich(
                    TextSpan(
                      text: notification.dbusNotification.appName,
                      children: [
                        TextSpan(
                          text:
                              ' • ${DateTime.now().difference(notification.createdAt).pretty(abbreviated: true, maxUnits: 1)}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                notification.dbusNotification.summary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(notification.dbusNotification.body),
              if (notification.dbusNotification.hints.imageData != null)
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Image.memory(
                    Uint8List.fromList(
                      notification.dbusNotification.hints.imageData!,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 8,
          top: 9,
          child: IconButton(
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
            ),
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: const Icon(MdiIcons.close),
            onPressed: onClose,
          ),
        ),
      ],
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nm/nm.dart';

class AccessPointLabel extends StatelessWidget {
  const AccessPointLabel({
    required this.accessPoint,
    super.key,
  });

  final NetworkManagerAccessPoint accessPoint;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: utf8.decode(accessPoint.ssid),
          ),
          TextSpan(
            text: '   ${(accessPoint.frequency / 1000).toStringAsFixed(1)} Ghz',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  color:
                      DefaultTextStyle.of(context).style.color!.withAlpha(128),
                ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

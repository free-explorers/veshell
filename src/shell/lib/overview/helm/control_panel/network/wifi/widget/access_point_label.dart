import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:nm/nm.dart';
import 'package:shell/l10n/l10n.dart';

class AccessPointLabel extends StatelessWidget {
  const AccessPointLabel({required this.accessPoint, super.key});

  final NetworkManagerAccessPoint accessPoint;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: utf8.decode(accessPoint.ssid)),
          TextSpan(
            text:
                '   ${context.measurement(accessPoint.frequency / 1000, 'GHz', decimalDigits: 1)}',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: DefaultTextStyle.of(context).style.color!.withAlpha(128),
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

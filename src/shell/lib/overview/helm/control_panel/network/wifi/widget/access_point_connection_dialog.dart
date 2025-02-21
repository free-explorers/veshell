import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/model/wifi_access_point.dart';

class AccessPointConnectionDialog extends HookConsumerWidget {
  const AccessPointConnectionDialog({
    required this.deviceAddress,
    required this.accessPoint,
    super.key,
  });
  final String deviceAddress;
  final WifiAccessPoint accessPoint;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                accessPoint.ssid,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              DropdownButtonFormField<String>(
                value: 'WPA-PSK',
                items: <String>[
                  'WPA-PSK',
                  'WPA-EAP',
                  'WPA2-PSK',
                  'WPA2-EAP',
                  'NONE',
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  // Handle the selected value here
                },
                decoration: const InputDecoration(
                  labelText: 'Key Management',
                ),
              ),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Password',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

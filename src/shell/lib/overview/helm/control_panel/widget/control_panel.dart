import 'package:flutter/material.dart';
import 'package:shell/overview/helm/control_panel/audio/widget/audio_control.dart';
import 'package:shell/overview/helm/control_panel/bluetooth/widget/bluetooth_control.dart';
import 'package:shell/overview/helm/control_panel/network/widget/network_control.dart';
import 'package:shell/overview/helm/control_panel/widget/session_controls.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: const [
              /* Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 48,
                            height: 48,
                            child: Placeholder(),
                          ),
                          const SizedBox(
                            width: 16,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Media title',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              Text(
                                'Media subtitle',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: Icon(MdiIcons.skipPrevious),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(MdiIcons.play),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(MdiIcons.skipNext),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(MdiIcons.close),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ), */
              AudioControl(),
              NetworkControl(),
              BluetoothControl(),
            ],
          ),
        ),
        const Divider(
          height: 2,
        ),
        const SizedBox(
          height: 8,
        ),
        const SessionControls(),
      ],
    );
  }
}

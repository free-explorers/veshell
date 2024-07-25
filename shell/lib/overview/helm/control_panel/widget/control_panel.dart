import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/helm/control_panel/widget/audio_output.dart';
import 'package:shell/overview/helm/control_panel/widget/session_controls.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
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
          const Divider(),
          const AudioOutputWidget(),
          Column(
            children: [
              ListTile(
                onTap: () {},
                leading: IconButton(
                  onPressed: () {},
                  icon: Icon(
                    MdiIcons.microphone,
                  ),
                ),
                title: Slider(
                  value: 0.9,
                  onChanged: (double value) {},
                ),
                trailing: Icon(MdiIcons.chevronDown),
              ),
            ],
          ),
          const Divider(),
          Column(
            children: [
              ListTile(
                leading: IconButton(
                  onPressed: () {},
                  icon: Icon(
                    MdiIcons.wifi,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Wifi not connected'),
                ),
                trailing: Icon(MdiIcons.chevronDown),
                onTap: () {},
              ),
            ],
          ),
          Column(
            children: [
              ListTile(
                leading: IconButton(
                  onPressed: () {},
                  icon: Icon(
                    MdiIcons.bluetooth,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Bluetooth not connected'),
                ),
                trailing: Icon(MdiIcons.chevronDown),
                onTap: () {},
              ),
            ],
          ),

          /* ListTile(
            leading: Icon(
              MdiIcons.brightness5,
            ),
            title: Slider(
              value: 0.7,
              onChanged: (double value) {},
            ),
          ), */
          const Spacer(),
          const Divider(
            height: 2,
          ),
          const SessionControls(),
        ],
      ),
    );
  }
}

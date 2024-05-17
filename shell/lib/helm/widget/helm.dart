import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/helm/widget/audio_output.dart';

class HelmWidget extends StatelessWidget {
  const HelmWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: () {},
                icon: Icon(MdiIcons.shipWheel),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(12),
                  iconSize: 28,
                ),
              ),
              const SizedBox(
                width: 24,
              ),
              Text(
                'Helm',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(
            height: 16,
          ),
          // Battery level
          // Multimedia
          // Wifi control
          // Bluetooth control
          // Brightness control
          // Output volume control
          // Output device picker
          // Input volume control
          // Input device picker
          // Restart / sleep / lock / logout / shutdown / hibernate
          Expanded(
            child: Card(
              elevation: 0,
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: Icon(MdiIcons.power),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Icon(MdiIcons.powerSleep),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Icon(MdiIcons.restart),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Icon(MdiIcons.logout),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Icon(MdiIcons.lock),
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

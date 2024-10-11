import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AudioOutputWidget extends StatelessWidget {
  const AudioOutputWidget({
    this.isExpanded = false,
    super.key,
  });
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  MdiIcons.tuneVertical,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(
                  width: 16,
                ),
                Expanded(
                  child: Text(
                    'Volume',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            onTap: () {},
            leading: IconButton(
              onPressed: () {},
              icon: Icon(
                MdiIcons.volumeHigh,
              ),
            ),
            title: Slider(
              value: 0.5,
              onChanged: (double value) {},
            ),
            trailing: Icon(MdiIcons.chevronUp),
          ),
          ColoredBox(
            color: Colors.black12,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: Icon(MdiIcons.check),
                  title: const Text('Output 1'),
                  onTap: () {},
                ),
              ],
            ),
          ),
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
    );
  }
}

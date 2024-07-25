import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/helm/monitor_panel/cpu_monitor/widget/cpu_monitor.dart';

class MonitorPanel extends StatelessWidget {
  const MonitorPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Battery level
          // Disk usages
          // CPU loading
          // Memory loading
          // Network usage

          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: Icon(
                    MdiIcons.battery,
                  ),
                  title: SliderTheme(
                    data: Theme.of(context).sliderTheme.copyWith(
                          thumbShape: SliderComponentShape.noThumb,
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                    child: const Slider(
                      value: 1,
                      onChanged: null,
                    ),
                  ),
                  trailing: const Text('100%'),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    bottom: 16,
                    right: 16,
                    top: 8,
                  ),
                  child: SegmentedButton(
                    segments: [
                      ButtonSegment(
                        icon: Icon(MdiIcons.speedometerSlow),
                        value: 'power_saver',
                      ),
                      ButtonSegment(
                        icon: Icon(MdiIcons.speedometerMedium),
                        value: 'balanced',
                      ),
                      ButtonSegment(
                        icon: Icon(MdiIcons.speedometer),
                        value: 'performance',
                      ),
                    ],
                    selected: const {'balanced'},
                    onSelectionChanged: (Set<String> value) {},
                  ),
                ),
              ],
            ),
          ),
          const Flexible(
              child: CpuMonitorWidget(
            isExpanded: true,
          )),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    MdiIcons.memory,
                  ),
                  title: SliderTheme(
                    data: Theme.of(context).sliderTheme.copyWith(
                          thumbShape: SliderComponentShape.noThumb,
                          disabledActiveTrackColor:
                              Theme.of(context).colorScheme.primary,
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                    child: const Slider(
                      value: 0.7,
                      onChanged: null,
                    ),
                  ),
                  trailing: Icon(MdiIcons.chevronDown),
                  onTap: () {},
                ),
              ],
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    MdiIcons.expansionCard,
                  ),
                  title: SliderTheme(
                    data: Theme.of(context).sliderTheme.copyWith(
                          thumbShape: SliderComponentShape.noThumb,
                          disabledActiveTrackColor:
                              Theme.of(context).colorScheme.primary,
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                    child: const Slider(
                      value: 0.7,
                      onChanged: null,
                    ),
                  ),
                  trailing: Icon(MdiIcons.chevronDown),
                  onTap: () {},
                ),
              ],
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    MdiIcons.downloadNetwork,
                  ),
                  title: SliderTheme(
                    data: Theme.of(context).sliderTheme.copyWith(
                          thumbShape: SliderComponentShape.noThumb,
                          disabledActiveTrackColor:
                              Theme.of(context).colorScheme.primary,
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                    child: const Slider(
                      value: 0.7,
                      onChanged: null,
                    ),
                  ),
                  trailing: Icon(MdiIcons.chevronDown),
                  onTap: () {},
                ),
              ],
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    MdiIcons.uploadNetwork,
                  ),
                  title: SliderTheme(
                    data: Theme.of(context).sliderTheme.copyWith(
                          thumbShape: SliderComponentShape.noThumb,
                          disabledActiveTrackColor:
                              Theme.of(context).colorScheme.primary,
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                    child: const Slider(
                      value: 0.7,
                      onChanged: null,
                    ),
                  ),
                  trailing: Icon(MdiIcons.chevronDown),
                  onTap: () {},
                ),
              ],
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    MdiIcons.harddisk,
                  ),
                  title: SliderTheme(
                    data: Theme.of(context).sliderTheme.copyWith(
                          thumbShape: SliderComponentShape.noThumb,
                          disabledActiveTrackColor:
                              Theme.of(context).colorScheme.primary,
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                    child: const Slider(
                      value: 0.6,
                      onChanged: null,
                    ),
                  ),
                  trailing: Icon(MdiIcons.chevronDown),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/helm/widget/helm.dart';
import 'package:shell/lookout/widget/search_engine.dart';

class Lookout extends HookConsumerWidget {
  const Lookout({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Expanded(child: SearchEngine()),
        const SizedBox(width: 16),
        AspectRatio(
          aspectRatio: 16 / 12,
          child: Material(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  HelmWidget(),
                  SizedBox(width: 8),
                  LookoutWidget(),
                  SizedBox(width: 8),
                  NotificationWidget(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NotificationWidget extends StatelessWidget {
  const NotificationWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: () {},
                icon: Icon(MdiIcons.bullhornVariant),
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
                'Notifications',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(
            height: 16,
          ),
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

class LookoutWidget extends StatelessWidget {
  const LookoutWidget({
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
                icon: Icon(MdiIcons.telescope),
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
                'Lookout',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(
            height: 16,
          ),
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
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    MdiIcons.chip,
                  ),
                  title: SliderTheme(
                    data: Theme.of(context).sliderTheme.copyWith(
                          thumbShape: SliderComponentShape.noThumb,
                          disabledActiveTrackColor:
                              Theme.of(context).colorScheme.primary,
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                    child: const Slider(
                      value: 0.9,
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

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/helm/monitoring_panel/disk_monitoring/provider/disk_space.dart';

class DiskUsageMonitoring extends HookConsumerWidget {
  const DiskUsageMonitoring({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diskSpaceState = ref.watch(diskSpaceStateProvider).where(
          (disk) =>
              disk.devicePath.startsWith('/dev') &&
              !disk.mountPath.startsWith('/boot'),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    MdiIcons.harddisk,
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child: Text(
                      'Disks',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            for (final disk in diskSpaceState)
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 8, right: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          disk.mountPath,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const Spacer(),
                        // bytes to smallest integere unit
                        Text(
                          switch (disk.availableSpace) {
                            > 1024 * 1024 * 1024 * 1024 =>
                              '${(disk.availableSpace / 1024 / 1024 / 1024 / 1024).round()} TB',
                            > 1024 * 1024 * 1024 =>
                              '${(disk.availableSpace / 1024 / 1024 / 1024).round()} GB',
                            > 1024 * 1024 =>
                              '${(disk.availableSpace / 1024 / 1024).round()} MB',
                            > 1024 =>
                              '${(disk.availableSpace / 1024).round()} KB',
                            _ => '${disk.availableSpace} B',
                          },
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: Theme.of(context).sliderTheme.copyWith(
                            thumbShape: SliderComponentShape.noThumb,
                            disabledActiveTrackColor:
                                Theme.of(context).colorScheme.primary,
                            trackShape: CustomSliderTrackShape(),
                            trackHeight: 8,
                          ),
                      child: SizedBox(
                        height: 24,
                        child: Slider(
                          //percentage of use
                          value: disk.usedSpace / disk.totalSize,
                          onChanged: null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CustomSliderTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    Offset offset = Offset.zero,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight!;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

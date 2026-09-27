import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/provider/monitor_arrangement.dart';
import 'package:shell/monitor/provider/monitor_placement.dart';
import 'package:shell/monitor/widget/monitor_arrangement/monitor_arrangement_canvas.dart';
import 'package:shell/settings/provider/state/monitor_setting_state.dart';
import 'package:shell/shared/widget/expandable_container.dart';

/// Editor to position monitors relative to each other, shown inline when the
/// "Arrange Monitors" setting is expanded.
///
/// The editor only manipulates **relative** positions: the arrangement is
/// normalised so its top-left sits at `(0, 0)` for display and dragging. On
/// Apply the relative layout is transposed to a `(0, 0)`-based absolute
/// location and written to `monitor/<connector>.json` through
/// `MonitorSettingState.setLocation`, which preserves the mode and scale
/// overrides. `Reset to default` stages only the locations in the compositor's
/// default left-to-right layout. Rust applies the change live and confirms it
/// through `monitor_layout_changed`. See `docs/specifications/monitor.md`.
class MonitorArrangementEditor extends HookConsumerWidget {
  const MonitorArrangementEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placements = ref.watch(monitorPlacementsProvider);
    final staged = useState<Map<String, Offset>>({});
    final selectedMonitorId = useState<String?>(null);
    final guides = useState<SnapResult?>(null);

    // Origin of the desired arrangement. The canvas works in a coordinate
    // space where this origin is (0, 0); Apply writes positions in that space.
    final base = arrangementOrigin(
      placements.map((placement) => placement.rect),
    );

    final relative = [
      for (final placement in placements)
        placement.copyWith(
          location:
              staged.value[placement.monitorId] ?? (placement.location - base),
        ),
    ];

    final initialRelative = {
      for (final placement in toRelativeArrangement(placements))
        placement.monitorId: placement.location,
    };
    final editedRelative = {
      for (final placement in relative) placement.monitorId: placement.location,
    };
    final originalLocations = {
      for (final placement in placements)
        placement.monitorId: placement.location,
    };
    final writes = changedLocations(originalLocations, editedRelative);
    final edited = changedLocations(initialRelative, editedRelative);
    final overlaps = arrangementsOverlap(
      relative.map((placement) => placement.rect),
    );
    final canApply = edited.isNotEmpty && !overlaps;

    void resetToDefault() {
      // Only the locations are reset: the mode and scale overrides are kept,
      // so the default layout uses each monitor's current logical size.
      staged.value = {
        for (final placement in autoArrangement(placements))
          placement.monitorId: placement.location,
      };
      guides.value = null;
    }

    void apply() {
      for (final entry in writes.entries) {
        final location = entry.value;
        ref
            .read(monitorSettingStateProvider(entry.key).notifier)
            .setLocation(
              Offset(location.dx.roundToDouble(), location.dy.roundToDouble()),
            );
      }
      ExpandableContainer.of(context).toggle();
    }

    // Height-adaptive so the `ExpandableContainer` hero flight can grow the
    // editor smoothly. The content is laid out at its full height and clipped
    // while the card is still small, so the real bottom bar never has to
    // shrink (which would overflow).
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: 420,
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(
                          color: theme.colorScheme.surfaceContainerLowest,
                          child: MonitorArrangementCanvas(
                            placements: relative,
                            selectedMonitorId: selectedMonitorId.value,
                            guides: guides.value,
                            onChanged: (monitorId, location) {
                              staged.value = {
                                ...staged.value,
                                monitorId: location,
                              };
                            },
                            onGuidesChanged: (value) => guides.value = value,
                            onSelected: (monitorId) =>
                                selectedMonitorId.value = monitorId,
                          ),
                        ),
                      ),
                      if (overlaps)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: theme.colorScheme.errorContainer,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Monitors overlap. Move them apart to '
                                    'apply.',
                                    style: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: resetToDefault,
                        child: const Text('Reset to default'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: canApply ? apply : null,
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

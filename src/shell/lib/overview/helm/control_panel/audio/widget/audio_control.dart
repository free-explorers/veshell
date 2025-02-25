import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/shared/pulseaudio/provider/default_sink.dart';
import 'package:shell/shared/pulseaudio/provider/default_source.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_audio.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_sink_list.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_source_list.dart';
import 'package:shell/shared/widget/expandable_card.dart';

enum OpenMode { output, input }

class AudioControl extends HookConsumerWidget {
  const AudioControl({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openMode = useState(OpenMode.output);
    print('openMode $openMode');
    return ExpandableCard(
      builder: (context, isExpanded) {
        print('build $openMode');
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            AudioOutputControl(
              isExpanded: isExpanded && openMode.value == OpenMode.output,
              onTap: () {
                if (!isExpanded || openMode.value == OpenMode.output) {
                  openMode.value = OpenMode.output;
                  ExpandableCard.of(context).toggle();
                } else {
                  openMode.value = OpenMode.output;
                }
              },
            ),
            if (isExpanded && openMode.value == OpenMode.output)
              const AudioOutputList(),
            AudioInputControl(
              isExpanded: isExpanded && openMode.value == OpenMode.input,
              onTap: () {
                if (!isExpanded || openMode.value == OpenMode.input) {
                  openMode.value = OpenMode.input;
                  ExpandableCard.of(context).toggle();
                } else {
                  openMode.value = OpenMode.input;
                }
              },
            ),
            if (isExpanded && openMode.value == OpenMode.input)
              const AudioInputList(),
          ],
        );
      },
    );
  }
}

class AudioOutputList extends HookConsumerWidget {
  const AudioOutputList({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultSink = ref.watch(defaultPulseSinkProvider);
    final sinkList = ref.watch(pulseSinkListProvider).requireValue;
    return Flexible(
      child: ColoredBox(
        color: Colors.black12,
        child: ListView.builder(
          shrinkWrap: true,
          itemBuilder: (context, index) {
            final sink = sinkList[index];
            return ListTile(
              leading: sink == defaultSink ? const Icon(MdiIcons.check) : null,
              title: Text(sink.description),
              onTap: () {
                ref
                    .read(pulseClientProvider.notifier)
                    .setDefaultSink(sink.name);
              },
            );
          },
          itemCount: sinkList.length,
        ),
      ),
    );
  }
}

class AudioInputList extends HookConsumerWidget {
  const AudioInputList({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultSource = ref.watch(defaultPulseSourceProvider);
    final sourceList = ref.watch(pulseSourceListProvider).requireValue;
    return Flexible(
      child: ColoredBox(
        color: Colors.black12,
        child: ListView.builder(
          shrinkWrap: true,
          itemBuilder: (context, index) {
            final source = sourceList[index];
            return ListTile(
              leading:
                  source == defaultSource ? const Icon(MdiIcons.check) : null,
              title: Text(source.description),
              onTap: () {
                ref
                    .read(pulseClientProvider.notifier)
                    .setDefaultSource(source.name);
              },
            );
          },
          itemCount: sourceList.length,
        ),
      ),
    );
  }
}

class AudioOutputControl extends HookConsumerWidget {
  const AudioOutputControl({
    required this.isExpanded,
    required this.onTap,
    super.key,
  });
  final bool isExpanded;
  final void Function() onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultSink = ref.watch(
      defaultPulseSinkProvider,
    );

    return ListTile(
      leading: IconButton(
        onPressed: () {
          ref
              .read(pulseClientProvider.notifier)
              .setSinkMute(defaultSink!.name, !defaultSink.mute);
        },
        icon: Icon(
          defaultSink?.mute ?? true ? MdiIcons.volumeOff : MdiIcons.volumeHigh,
        ),
      ),
      title: Slider(
        value: defaultSink?.mute ?? true ? 0.0 : defaultSink?.volume ?? 0.0,
        onChanged: defaultSink == null
            ? null
            : (value) {
                if (defaultSink.mute) {
                  ref
                      .read(pulseClientProvider.notifier)
                      .setSinkMute(defaultSink.name, false);
                }
                ref
                    .read(pulseClientProvider.notifier)
                    .setSinkVolume(defaultSink.name, value);
              },
      ),
      trailing: IconButton.filledTonal(
        onPressed: onTap,
        icon: Icon(
          isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
        ),
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class AudioInputControl extends HookConsumerWidget {
  const AudioInputControl({
    required this.isExpanded,
    required this.onTap,
    super.key,
  });
  final bool isExpanded;
  final void Function() onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultSource = ref.watch(
      defaultPulseSourceProvider,
    );

    return ListTile(
      leading: IconButton(
        onPressed: () {
          ref
              .read(pulseClientProvider.notifier)
              .setSourceMute(defaultSource!.name, !defaultSource.mute);
        },
        icon: Icon(
          defaultSource?.mute ?? true
              ? MdiIcons.microphoneOff
              : MdiIcons.microphone,
        ),
      ),
      title: Slider(
        value: defaultSource?.mute ?? true
            ? 0.0
            : min(defaultSource?.volume ?? 0.0, 1),
        onChanged: defaultSource == null
            ? null
            : (value) {
                if (defaultSource.mute) {
                  ref
                      .read(pulseClientProvider.notifier)
                      .setSourceMute(defaultSource.name, false);
                }
                ref
                    .read(pulseClientProvider.notifier)
                    .setSourceVolume(defaultSource.name, value);
              },
      ),
      trailing: IconButton.filledTonal(
        onPressed: onTap,
        icon: Icon(
          isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
        ),
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

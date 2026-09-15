import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/capture/model/screen_cast_consent/screen_cast_consent.serializable.dart';
import 'package:shell/capture/provider/screen_cast_consent.dart';

/// The trusted screen cast consent picker.
///
/// The picker names the requesting application and the shareable outputs;
/// it never shows pixel previews of what it offers. Approving or
/// cancelling reports the decision to the compositor, which revalidates
/// the choice in Rust before anything flows.
class ScreenCastConsentPicker extends HookConsumerWidget {
  const ScreenCastConsentPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final consent = ref.watch(screenCastConsentProvider);
    final selectedSource = useState<String?>(null);

    if (consent == null) {
      return const SizedBox.shrink();
    }
    final approvedSource =
        selectedSource.value ?? _resolvedSourceId(consent.sources);

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Share your screen?',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                consent.appName.isEmpty
                    ? 'An application wants to share an output.'
                    : '${consent.appName} wants to share an output.',
              ),
              const SizedBox(height: 24),
              for (final source in consent.sources) ...[
                RadioListTile<String>(
                  value: source.id,
                  groupValue: approvedSource,
                  title: Text(source.label),
                  onChanged: (value) {
                    if (value != null) {
                      selectedSource.value = value;
                    }
                  },
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: ref
                        .read(screenCastConsentProvider.notifier)
                        .cancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: approvedSource == null
                        ? null
                        : () => ref
                            .read(screenCastConsentProvider.notifier)
                            .approve(approvedSource),
                    child: const Text('Share'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// With single-output sessions the only source is the implied choice, so
  /// the picker still requires the explicit confirmation.
  String? _resolvedSourceId(List<ScreenCastSourceMessage> sources) =>
      sources.isEmpty ? null : sources.first.id;
}

/// Mounts the picker into the shell tree: mounted per monitor by the
/// monitor widget, it only builds surface where a flow is actually open.
class ScreenCastConsentHost extends HookConsumerWidget {
  const ScreenCastConsentHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(screenCastConsentProvider);
    if (consent == null) {
      return const SizedBox.shrink();
    }
    // The flow owns every input while it is open: the picker is the only
    // thing that reacts until a decision is delivered.
    return Center(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Align(
          alignment: Alignment.center,
          child: ScreenCastConsentPicker(),
        ),
      ),
    );
  }
}

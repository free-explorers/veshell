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
    final approvedSource = selectedSource.value;

    // Never upscale the request kinds in the copy: a WINDOW-only request
    // talks about windows, a mixed one names both explicitly (spec 8.2:
    // the picker is filtered by the request's types, never substituted).
    final offersOutputs =
        consent.sources.any((source) => source.kind == CaptureSourceKind.outputs);
    final offersWindows =
        consent.sources.any((source) => source.kind == CaptureSourceKind.windows);

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                switch ((offersOutputs, offersWindows)) {
                  (true, false) => 'Share your screen?',
                  (false, true) => 'Share a window?',
                  _ => 'Share a screen or a window?',
                },
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                consent.appName.isEmpty
                    ? 'An application wants shared content.'
                    : '${consent.appName} wants to share with you.',
              ),
              const SizedBox(height: 24),
              // Windows first, then screens: Brave and Chromium send
              // `types: 3` even for a window flow, so a mixed, grouped
              // list is the normal case there. Nothing is preselected —
              // Share stays disabled until an explicit choice, so a
              // careless click can never approve the wrong target. The
              // list scrolls: a busy desktop can offer more windows than
              // fit the dialog.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final group in [
                        (CaptureSourceKind.windows, 'Windows'),
                        (CaptureSourceKind.outputs, 'Screens'),
                      ]) ...[
                        if (offersOutputs &&
                            offersWindows &&
                            consent.sources.any((s) => s.kind == group.$1))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2, left: 8),
                            child: Text(
                              group.$2,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        for (final source in consent.sources.where(
                          (s) => s.kind == group.$1,
                        ))
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
                    ],
                  ),
                ),
              ),
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
                    child: Text(
                      offersOutputs && offersWindows
                          ? 'Share'
                          : offersWindows
                              ? 'Share window'
                              : 'Share',
                    ),
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
          // Keying by consent token resets the radio selection when a
          // new flow replaces the current one, so a stale source id can
          // never stay selected across requests.
          child: ScreenCastConsentPicker(key: ValueKey(consent.consentToken)),
        ),
      ),
    );
  }
}

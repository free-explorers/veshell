import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';

class PolkitAuthenticationDialog extends HookConsumerWidget {
  const PolkitAuthenticationDialog(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passwordState = useState('');

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                context.l10n.authenticationRequired,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              Text(message),
              const SizedBox(height: 32),
              TextField(
                onChanged: (value) {
                  passwordState.value = value;
                },
                onSubmitted: (value) {
                  Navigator.of(context).pop(value);
                },
                autofocus: true,
                style: Theme.of(context).textTheme.titleMedium,
                decoration: InputDecoration(
                  hintText: context.l10n.password,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  fillColor: Theme.of(context).colorScheme.surface,
                  filled: true,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(context.l10n.cancel),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: passwordState.value.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop(passwordState.value);
                          },
                    child: Text(context.l10n.authenticate),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

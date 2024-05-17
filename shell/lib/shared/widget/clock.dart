import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shell/shared/provider/now_date_time.dart';

class ClockWidget extends HookConsumerWidget {
  const ClockWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useState(DateTime.now());
    ref.listen(nowDateTimeProvider, (prev, next) {
      if (prev?.minute != next.minute) now.value = next;
    });
    final currentTime = DateFormat('hh:mm a').format(now.value);
    final currentDate = DateFormat('MMMM dd, yyyy').format(now.value);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          currentTime,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(width: 16),
        Text(
          currentDate,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

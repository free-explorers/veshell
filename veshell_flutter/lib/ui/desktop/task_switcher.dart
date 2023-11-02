import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/common/app_icon.dart';
import 'package:zenith/ui/common/state/tasks_provider.dart';
import 'package:zenith/ui/common/state/xdg_toplevel_state.dart';
import 'package:zenith/ui/desktop/state/task_switcher_provider.dart';

class TaskSwitcherWidget extends ConsumerStatefulWidget {
  const TaskSwitcherWidget({super.key});

  @override
  ConsumerState<TaskSwitcherWidget> createState() => _TaskSwitcherState();
}

class _TaskSwitcherState extends ConsumerState<TaskSwitcherWidget> {
  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).tasks;
    final children = tasks.reversed.indexed.map((tuple) {
      final (int index, int task) = tuple;
      return TaskSwitcherItem(
        index: index,
        task: task,
      );
    }).toList();

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 20,
          sigmaY: 20,
        ),
        child: Container(
          color: Colors.grey.shade900.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Builder(builder: (context) {
              if (children.isEmpty) {
                return const Text(
                  "No windows open",
                  style: TextStyle(color: Colors.white, fontSize: 20),
                );
              }
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: children,
              );
            }),
          ),
        ),
      ),
    );
  }
}

class TaskSwitcherItem extends ConsumerWidget {
  final int index;
  final int task;

  const TaskSwitcherItem({
    super.key,
    required this.index,
    required this.task,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? child) {
        int taskSwitcherIndex = ref.watch(taskSwitcherProvider.select((value) => value.index));
        return Container(
          width: 140,
          decoration: BoxDecoration(
            color: taskSwitcherIndex == index ? Colors.white24 : null,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 130,
              child: AppIconByViewId(viewId: task),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
              left: 8,
              right: 8,
            ),
            child: Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                return Text(
                  ref.watch(xdgToplevelStatesProvider(task)).title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

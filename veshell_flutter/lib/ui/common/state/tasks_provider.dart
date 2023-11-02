import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/platform_api.dart';
import 'package:zenith/ui/common/state/xdg_toplevel_state.dart';

part '../../../generated/ui/common/state/tasks_provider.freezed.dart';

part '../../../generated/ui/common/state/tasks_provider.g.dart';

@Riverpod(keepAlive: true)
class Tasks extends _$Tasks {
  @override
  TasksState build() {
    ref.listen(windowMappedStreamProvider, (_, next) {
      next.whenData((int viewId) {
        state = state.copyWith(
          tasks: state.tasks.add(viewId),
          diff: [AddDiffOperation(endOfCollection, viewId)].lockUnsafe,
        );
        ref.read(xdgToplevelStatesProvider(viewId)).focusNode.requestFocus();
      });
    });

    ref.listen(windowUnmappedStreamProvider, (_, next) {
      next.whenData((int viewId) {
        state = state.copyWith(
          tasks: state.tasks.remove(viewId),
          diff: [RemoveDiffOperation(viewId)].lockUnsafe,
        );
        ref
            .read(xdgToplevelStatesProvider(viewId))
            .focusNode
            .unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      });
    });

    return TasksState(
      tasks: IList(),
      diff: IList(),
    );
  }

  void putInFront(int viewId) {
    state = state.copyWith(
      tasks: state.tasks.remove(viewId).add(viewId),
      diff: [ReorderDiffOperation(endOfCollection, viewId)].lockUnsafe,
    );
  }
}

@freezed
class TasksState with _$TasksState {
  const factory TasksState({
    required IList<int> tasks,

    /// The list of operations applied to the previous tasks list to obtain current one.
    /// The desktop window stack will use this diff to delay the removal of windows in order to
    /// animate their closing instead of synchronizing with the tasks list immediately.
    required IList<DiffOperation<int>> diff,
  }) = _TasksState;
}

sealed class DiffOperation<T> {
  IList<T> applyOn(IList<T> list);
}

class RemoveDiffOperation<T> extends DiffOperation<T> {
  final T element;

  RemoveDiffOperation(this.element);

  @override
  IList<T> applyOn(IList<T> list) => list.remove(element);
}

class ReorderDiffOperation<T> extends DiffOperation<T> {
  final IndexFunction<T> index;
  final T element;

  ReorderDiffOperation(this.index, this.element);

  @override
  IList<T> applyOn(IList<T> list) {
    list = list.remove(element);
    return list.insert(index(list), element);
  }
}

class AddDiffOperation<T> extends DiffOperation<T> {
  final IndexFunction<T> index;
  final T element;

  AddDiffOperation(this.index, this.element);

  @override
  IList<T> applyOn(IList<T> list) => list.insert(index(list), element);
}

typedef IndexFunction<T> = int Function(IList<T>);

int endOfCollection<T>(Iterable<T> list) => list.length;

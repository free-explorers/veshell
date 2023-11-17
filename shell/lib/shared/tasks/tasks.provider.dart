import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:veshell/manager/platform_api/platform_api.provider.dart';
import 'package:veshell/shared/tasks/tasks.model.dart';
import 'package:veshell/shared/wayland/xdg_toplevel/xdg_toplevel.provider.dart';

part 'tasks.provider.g.dart';

@Riverpod(keepAlive: true)
class Tasks extends _$Tasks {
  @override
  TasksState build() {
    ref
      ..listen(windowMappedStreamProvider, (_, next) {
        next.whenData((int viewId) {
          state = state.copyWith(
            tasks: state.tasks.add(viewId),
            diff: [AddDiffOperation(endOfCollection<int>, viewId)].lockUnsafe,
          );
          ref.read(xdgToplevelStatesProvider(viewId)).focusNode.requestFocus();
        });
      })
      ..listen(windowUnmappedStreamProvider, (_, next) {
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
      tasks: IList<int>(),
      diff: IList<DiffOperation<int>>(),
    );
  }

  void putInFront(int viewId) {
    state = state.copyWith(
      tasks: state.tasks.remove(viewId).add(viewId),
      diff: [ReorderDiffOperation(endOfCollection<int>, viewId)].lockUnsafe,
    );
  }
}

sealed class DiffOperation<T> {
  IList<T> applyOn(IList<T> list);
}

class RemoveDiffOperation<T> extends DiffOperation<T> {
  RemoveDiffOperation(this.element);
  final T element;

  @override
  IList<T> applyOn(IList<T> list) => list.remove(element);
}

class ReorderDiffOperation<T> extends DiffOperation<T> {
  ReorderDiffOperation(this.index, this.element);
  final IndexFunction<T> index;
  final T element;

  @override
  IList<T> applyOn(IList<T> list) {
    list = list.remove(element);
    return list.insert(index(list), element);
  }
}

class AddDiffOperation<T> extends DiffOperation<T> {
  AddDiffOperation(this.index, this.element);
  final IndexFunction<T> index;
  final T element;

  @override
  IList<T> applyOn(IList<T> list) => list.insert(index(list), element);
}

typedef IndexFunction<T> = int Function(IList<T>);

int endOfCollection<T>(Iterable<T> list) => list.length;

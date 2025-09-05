import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

class StateDevView extends HookConsumerWidget {
  const StateDevView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MonitorStateViewer(),
          Divider(),
        ],
      ),
    );
  }
}

class MonitorStateViewer extends HookConsumerWidget {
  const MonitorStateViewer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitorList = ref.watch(connectedMonitorListProvider);
    return DataContainer(
      title: 'Monitors',
      children: [
        ...monitorList.map(
          (e) => ExpandableDataRow(
            isExpanded: true,
            property: e.name,
            builder: (context) => DataContainer(
              children: [
                DataRow(value: e.description, property: 'description'),
                ExpandableDataRow(
                  property: 'physicalProperties',
                  builder: (context) {
                    return DataContainer(
                      children: [
                        DataRow(
                          value: e.physicalProperties.size.toString(),
                          property: 'size',
                        ),
                        DataRow(
                          value: e.physicalProperties.make,
                          property: 'make',
                        ),
                        DataRow(
                          value: e.physicalProperties.model,
                          property: 'model',
                        ),
                      ],
                    );
                  },
                ),
                DataRow(value: e.scale.toString(), property: 'scale'),
                DataRow(value: e.location.toString(), property: 'location'),
                DataRow(
                  value: e.currentMode.toString(),
                  property: 'currentMode',
                ),
                DataRow(
                  value: e.preferredMode.toString(),
                  property: 'preferredMode',
                ),
                ExpandableDataRow(
                  isExpanded: true,
                  property: 'Screens',
                  builder: (context) {
                    return Consumer(
                      builder: (context, ref, child) {
                        final monitorConfiguration = ref.watch(
                          monitorConfigurationStateProvider(e.name),
                        );
                        return DataContainer(
                          children: [
                            for (final screenConfiguration
                                in monitorConfiguration.screenList) ...[
                              DataRow(
                                value: screenConfiguration.flex.toString(),
                                property: 'flex',
                              ),
                              ExpandableDataRow(
                                isExpanded: true,
                                property: screenConfiguration.screenId,
                                builder: (context) => ScreenStateViewer(
                                  screenId: screenConfiguration.screenId,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ScreenStateViewer extends HookConsumerWidget {
  const ScreenStateViewer({required this.screenId, super.key});
  final String screenId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenState = ref.watch(screenStateProvider(screenId));
    return DataContainer(
      children: [
        DataRow(
          value: screenState.selectedIndex.toString(),
          property: 'selectedIndex',
        ),
        ExpandableDataRow(
          isExpanded: true,
          property: 'workspaceList [${screenState.workspaceList.length}]',
          builder: (context) {
            return DataContainer(
              children: screenState.workspaceList.map(
                (e) {
                  final isSelected = screenState.workspaceList.indexOf(e) ==
                      screenState.selectedIndex;
                  return ExpandableDataRow(
                    isExpanded: isSelected,
                    property: "$e ${isSelected ? '- Selected' : ''}",
                    builder: (context) => WorkspaceStateViewer(
                      workspaceId: e,
                    ),
                  );
                },
              ).toList(),
            );
          },
        ),
      ],
    );
  }
}

class WorkspaceStateViewer extends HookConsumerWidget {
  const WorkspaceStateViewer({required this.workspaceId, super.key});
  final String workspaceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceState = ref.watch(workspaceStateProvider(workspaceId));
    return DataContainer(
      children: [
        DataRow(
          value: workspaceState.selectedIndex.toString(),
          property: 'selectedIndex',
        ),
        DataRow(
          value: workspaceState.visibleLength.toString(),
          property: 'visibleLength',
        ),
        DataRow(
          value: workspaceState.category.toString(),
          property: 'category',
        ),
        DataRow(
          value: workspaceState.forcedCategory.toString(),
          property: 'forcedCategory',
        ),
        ExpandableDataRow(
          isExpanded: true,
          property:
              'tileableWindowList [${workspaceState.tileableWindowList.length}]',
          builder: (context) => DataContainer(
            children: workspaceState.tileableWindowList
                .map(
                  (e) => ExpandableDataRow(
                    isExpanded: workspaceState.tileableWindowList.indexOf(e) ==
                        workspaceState.selectedIndex,
                    property: e.toString(),
                    builder: (context) => PersistentWindowStateViewer(
                      windowId: e,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class PersistentWindowStateViewer extends HookConsumerWidget {
  const PersistentWindowStateViewer({required this.windowId, super.key});
  final PersistentWindowId windowId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persistentWindowState =
        ref.watch(persistentWindowStateProvider(windowId));
    return DataContainer(
      children: [
        ExpandableDataRow(
          property: 'properties',
          builder: (context) => DataContainer(
            children: [
              DataRow(
                value: persistentWindowState.properties.title,
                property: 'title',
              ),
              DataRow(
                value: persistentWindowState.properties.appId,
                property: 'appId',
              ),
              DataRow(
                value: persistentWindowState.properties.windowClass,
                property: 'windowClass',
              ),
              DataRow(
                value: persistentWindowState.properties.startupId,
                property: 'startupId',
              ),
              DataRow(
                value: persistentWindowState.properties.pid.toString(),
                property: 'pid',
              ),
            ],
          ),
        ),
        if (persistentWindowState.metaWindowId == null)
          const DataRow(value: null, property: 'metaWindowId')
        else
          ExpandableDataRow(
            property: 'metaWindow ${persistentWindowState.metaWindowId}',
            builder: (context) => MetaWindowStateViewer(
              metaWindowId: persistentWindowState.metaWindowId!,
            ),
          ),
      ],
    );
  }
}

class MetaWindowStateViewer extends HookConsumerWidget {
  const MetaWindowStateViewer({required this.metaWindowId, super.key});
  final MetaWindowId metaWindowId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaWindowState = ref.watch(metaWindowStateProvider(metaWindowId));
    return DataContainer(
      children: [
        DataRow(
          value: metaWindowState.title,
          property: 'title',
        ),
        DataRow(
          value: metaWindowState.appId,
          property: 'appId',
        ),
        DataRow(
          value: metaWindowState.windowClass,
          property: 'windowClass',
        ),
        DataRow(
          value: metaWindowState.startupId,
          property: 'startupId',
        ),
        DataRow(
          value: metaWindowState.pid.toString(),
          property: 'pid',
        ),
        DataRow(
          value: metaWindowState.geometry?.toString(),
          property: 'geometry',
        ),
        Row(
          children: [
            SizedBox(
              width: (metaWindowState.geometry?.width ?? 200) / 5,
              height: (metaWindowState.geometry?.height ?? 100) / 5,
              child: FittedBox(
                child: SizedBox(
                  width: metaWindowState.geometry?.width ?? 100,
                  height: metaWindowState.geometry?.height ?? 40,
                  child: MetaSurfaceWidget(
                    metaWindowId: metaWindowId,
                    decorated: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DataContainer extends StatelessWidget {
  const DataContainer({required this.children, super.key, this.title});
  final String? title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).hoverColor,
            width: 2,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Text(title ?? ''),
          ListView.separated(
            shrinkWrap: true,
            itemBuilder: (context, index) {
              return children[index];
            },
            separatorBuilder: (context, index) {
              return const Divider(
                height: 2,
              );
            },
            itemCount: children.length,
          ),
        ],
      ),
    );
  }
}

class DataRow extends StatelessWidget {
  const DataRow({required this.value, required this.property, super.key});
  final String property;
  final String? value;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
          ),
          SizedBox(width: 100, child: Text(property)),
          const SizedBox(
            width: 24,
          ),
          Text(value ?? 'null'),
        ],
      ),
    );
  }
}

class ExpandableDataRow extends HookWidget {
  const ExpandableDataRow({
    required this.property,
    required this.builder,
    super.key,
    this.isExpanded = false,
  });
  final String property;
  final WidgetBuilder builder;
  final bool isExpanded;
  @override
  Widget build(BuildContext context) {
    final isExpandedState = useState(isExpanded);
    return Column(
      children: [
        InkWell(
          onTap: () => isExpandedState.value = !isExpandedState.value,
          child: SizedBox(
            height: 24,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Icon(
                    isExpandedState.value
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                  ),
                ),
                Text(property),
              ],
            ),
          ),
        ),
        if (isExpandedState.value) ...[
          const Divider(
            height: 2,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Builder(builder: builder),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/widget/expandable_container.dart';

class ExpandableSearchResult<T> extends HookConsumerWidget
    implements SettingPropertyValueEditor<T> {
  const ExpandableSearchResult({
    required this.path,
    required this.property,
    required this.buildValue,
    required this.buildEditor,
    super.key,
  });

  @override
  final String path;

  @override
  final SettingProperty<T> property;

  final Widget Function(
    BuildContext context,
    dynamic value, {
    required bool isExpanded,
  }) buildValue;

  final Widget Function(BuildContext context, {required bool isExpanded})
      buildEditor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(jsonValueByPathProvider(path));

    return ExpandableContainer(
      builder: (BuildContext context, {required bool isExpanded}) {
        final tile = ListTile(
          onTap: isExpanded
              ? null
              : () {
                  ExpandableContainer.of(context).toggle();
                },
          title: Text(property.name),
          subtitle: Text(property.description),
          trailing: buildValue(context, value, isExpanded: isExpanded),
        );

        return Card(
          color: isExpanded ? null : Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile,
              if (isExpanded)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: buildEditor(context, isExpanded: isExpanded),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

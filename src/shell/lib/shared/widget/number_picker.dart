import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/shell_icon.dart';

class NumberPicker extends HookConsumerWidget {
  const NumberPicker({
    required this.value,
    required this.onValueChange,
    this.allowKeyboardInput = true,
    this.maxValue,
    this.minValue,
    super.key,
  });
  final int value;

  /// Whether the count field can be edited with the keyboard. The `+`/`-`
  /// buttons always work; this only gates direct text input.
  final bool allowKeyboardInput;
  final void Function(int value) onValueChange;
  final int? minValue;
  final int? maxValue;

  /// The height the picker is drawn at, its ends rounded to half of it.
  static const height = 36.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textcontroller = useTextEditingController(text: value.toString());
    useEffect(() {
      textcontroller.text = value.toString();
      return null;
    }, [value]);
    return Container(
      constraints: const BoxConstraints(maxHeight: height),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        color: Colors.white10,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              if (minValue != null &&
                  int.parse(textcontroller.text) <= minValue!) {
                return;
              }
              onValueChange(int.parse(textcontroller.text) - 1);
            },
            icon: const ShellIcon(MdiIcons.minus),
            iconSize: 20,
            style: IconButton.styleFrom(shape: LinearBorder.none),
          ),
          SizedBox(
            width: 40,
            child: TextField(
              enabled: allowKeyboardInput,
              controller: textcontroller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: OutlineInputBorder(borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
                filled: true,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              if (maxValue != null &&
                  int.parse(textcontroller.text) >= maxValue!) {
                return;
              }
              onValueChange(int.parse(textcontroller.text) + 1);
            },
            icon: const ShellIcon(MdiIcons.plus),
            iconSize: 20,
            style: IconButton.styleFrom(shape: LinearBorder.none),
          ),
        ],
      ),
    );
  }
}

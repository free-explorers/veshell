import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class NumberPicker extends HookConsumerWidget {
  const NumberPicker({
    required this.value,
    required this.onValueChange,
    this.maxValue,
    this.minValue,
    super.key,
  });
  final int value;
  final Function(int value) onValueChange;
  final int? minValue;
  final int? maxValue;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textcontroller = useTextEditingController(text: value.toString());
    useEffect(
      () {
        textcontroller.text = value.toString();
        return null;
      },
      [value],
    );
    return Container(
      constraints: const BoxConstraints(maxHeight: 36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
            icon: const Icon(Icons.remove),
            iconSize: 20,
            style: IconButton.styleFrom(
              shape: LinearBorder.none,
            ),
          ),
          SizedBox(
            width: 40,
            child: TextField(
              enabled: false,
              controller: textcontroller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.all(0),
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
            icon: const Icon(Icons.add),
            iconSize: 20,
            style: IconButton.styleFrom(
              shape: LinearBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}

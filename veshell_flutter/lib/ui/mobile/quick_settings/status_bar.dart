import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/util/state/screen_state.dart';
import 'package:zenith/ui/mobile/quick_settings/digital_clock.dart';

/// The status bar has the same height as the notch, and widgets inside it are scaled the same
/// regardless of the ratio between the physical and logical pixel.
class StatusBar extends ConsumerStatefulWidget {
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;

  const StatusBar({
    Key? key,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  }) : super(key: key);

  @override
  ConsumerState<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends ConsumerState<StatusBar> {
  late double pixelRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    pixelRatio = MediaQuery.of(context).devicePixelRatio;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: widget.onVerticalDragStart,
      onVerticalDragUpdate: widget.onVerticalDragUpdate,
      onVerticalDragEnd: widget.onVerticalDragEnd,
      onDoubleTap: () => ref.read(screenStateNotifierProvider.notifier).lockAndTurnOff(),
      child: Container(
        height: MediaQuery.of(context).padding.top,
        color: Colors.black38,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: physicalToLogicalPixels(12)),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return DefaultTextStyle(
                style: TextStyle(
                  fontSize: constraints.maxHeight * 0.8,
                  height: null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Dividing by pixelRatio makes the widget have the same size regardless of the
                    // size of a logical pixel.
                    SizedBox(width: physicalToLogicalPixels(30)),
                    const DigitalClock(),
                    const Spacer(),
                    // Icon(
                    //   Icons.wifi,
                    //   color: Colors.white,
                    //   size: constraints.maxHeight,
                    // ),
                    // Icon(
                    //   Icons.signal_cellular_4_bar,
                    //   color: Colors.white,
                    //   size: constraints.maxHeight,
                    // ),
                    // SizedBox(width: physicalToLogicalPixels(30)),
                    // const Text(
                    //   "98%",
                    //   style: TextStyle(
                    //     fontWeight: FontWeight.bold,
                    //     color: Colors.white,
                    //   ),
                    // ),
                    // Icon(
                    //   Icons.battery_charging_full,
                    //   color: Colors.white,
                    //   size: constraints.maxHeight,
                    // ),
                    SizedBox(width: physicalToLogicalPixels(30)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double physicalToLogicalPixels(double pixels) {
    return pixels / pixelRatio;
  }
}

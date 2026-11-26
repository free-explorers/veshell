import 'package:defer_pointer/defer_pointer.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_id_per_surface_id.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/pointer/provider/pointer_focus.manager.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/widget/surface/view_input_listener.dart';

const _surfaceId = 7;
const _metaWindowId = 'w1';
const _surfaceSize = Size(200, 150);

class _FixedSurfaceState extends WlSurfaceState {
  @override
  WlSurface build(int surfaceId) => WlSurface(
    surfaceId: surfaceId,
    role: SurfaceRole.xdgToplevel,
    texture: const SurfaceTexture(id: 1, size: _surfaceSize),
    scale: 1,
    subsurfacesBelow: IList(),
    subsurfacesAbove: IList(),
    inputRegion: Offset.zero & _surfaceSize,
  );
}

class _NoMonitor extends MonitorByName {
  @override
  Monitor? build(String monitorName) => null;
}

class _MappedSurface extends MetaWindowIdPerSurfaceId {
  @override
  MetaWindowId? build(SurfaceId surfaceId) => _metaWindowId;
}

/// Records the patches it receives instead of sending them to the platform,
/// where an offset that is not finite fails to serialize.
class _RecordingMetaWindowState extends MetaWindowState {
  static final patches = <MetaWindowPatchMessage>[];

  @override
  MetaWindow build(String id) => MetaWindow(
    id: id,
    pid: 1,
    mapped: true,
    surfaceId: _surfaceId,
    needDecoration: false,
    gameModeActivated: false,
    scaleRatio: 1,
  );

  @override
  Future<void> patch(
    MetaWindowPatchMessage patch, {
    bool propagate = true,
  }) async {
    patches.add(patch);
  }
}

Future<ProviderContainer> _pumpUnder(
  WidgetTester tester,
  Widget Function(Widget surface) wrap,
) async {
  final container = ProviderContainer(
    overrides: [
      wlSurfaceStateProvider(_surfaceId).overrideWith(_FixedSurfaceState.new),
      monitorByNameProvider('M1').overrideWith(_NoMonitor.new),
      metaWindowIdPerSurfaceIdProvider(
        _surfaceId,
      ).overrideWith(_MappedSurface.new),
      metaWindowStateProvider(
        _metaWindowId,
      ).overrideWith(_RecordingMetaWindowState.new),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: CurrentMonitorName(
          name: 'M1',
          child: DeferredPointerHandler(
            child: Align(
              alignment: Alignment.topLeft,
              child: wrap(
                ViewInputListener(
                  surfaceId: _surfaceId,
                  surfaceSize: _surfaceSize,
                  child: SizedBox.fromSize(size: _surfaceSize),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  setUp(_RecordingMetaWindowState.patches.clear);

  testWidgets('a laid-out surface reports its render origin', (tester) async {
    final container = await _pumpUnder(
      tester,
      (surface) =>
          Transform.translate(offset: const Offset(30, 40), child: surface),
    );

    expect(_RecordingMetaWindowState.patches, [
      const MetaWindowPatchMessage.updateRenderOrigin(
        id: _metaWindowId,
        value: Offset(30, 40),
      ),
    ]);
    expect(
      container.read(surfaceRenderOriginsProvider)[_surfaceId],
      const Offset(30, 40),
    );
  });

  testWidgets(
    'a surface under a degenerate transform reports no render origin',
    (tester) async {
      // A perspective row of zeros projects every point to w = 0, so
      // `localToGlobal` yields NaN, as a collapsing or zero-size ancestor can.
      final container = await _pumpUnder(
        tester,
        (surface) => Transform(transform: Matrix4.zero(), child: surface),
      );

      expect(_RecordingMetaWindowState.patches, isEmpty);
      expect(
        container.read(surfaceRenderOriginsProvider),
        isNot(contains(_surfaceId)),
      );
    },
  );

  testWidgets(
    'a surface on a page kept alive off screen reports its origin on return',
    (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      await _pumpUnder(
        tester,
        (surface) => SizedBox.fromSize(
          size: const Size(400, 300),
          child: PageView(
            controller: controller,
            scrollDirection: Axis.vertical,
            children: [
              _KeptAlive(child: surface),
              const SizedBox.expand(),
            ],
          ),
        ),
      );
      expect(_RecordingMetaWindowState.patches, [
        const MetaWindowPatchMessage.updateRenderOrigin(
          id: _metaWindowId,
          value: Offset.zero,
        ),
      ]);
      _RecordingMetaWindowState.patches.clear();

      // Out of view, the page is parked: built, but neither laid out nor
      // painted, so a rebuild there measures a NaN origin.
      controller.jumpToPage(1);
      await tester.pump();
      tester
          .element(find.byType(ViewInputListener, skipOffstage: false))
          .markNeedsBuild();
      await tester.pump();
      await tester.pump();
      expect(_RecordingMetaWindowState.patches, isEmpty);

      controller.jumpToPage(0);
      await tester.pump();
      tester.element(find.byType(ViewInputListener)).markNeedsBuild();
      await tester.pump();
      await tester.pump();
      expect(
        _RecordingMetaWindowState.patches,
        contains(
          const MetaWindowPatchMessage.updateRenderOrigin(
            id: _metaWindowId,
            value: Offset.zero,
          ),
        ),
      );
    },
  );
}

class _KeptAlive extends StatefulWidget {
  const _KeptAlive({required this.child});

  final Widget child;

  @override
  State<_KeptAlive> createState() => _KeptAliveState();
}

class _KeptAliveState extends State<_KeptAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

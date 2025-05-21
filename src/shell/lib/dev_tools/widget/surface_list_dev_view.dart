import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum SurfaceType { xdgToplevel, x11Surface }

class SurfaceListDevView extends HookConsumerWidget {
  const SurfaceListDevView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = useState(SurfaceType.xdgToplevel);
    return Material(
      color: Theme.of(context).colorScheme.surface.withAlpha(240),
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: ListView(
              children: SurfaceType.values
                  .map(
                    (e) => ListTile(
                      selected: selectedCategory.value == e,
                      title: switch (e) {
                        SurfaceType.xdgToplevel => const Text('XDG Toplevel'),
                        SurfaceType.x11Surface => const Text('X11 Surface'),
                      },
                      onTap: () => selectedCategory.value = e,
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface.withAlpha(240),
              child: /*  switch (selectedCategory.value) {
                SurfaceType.xdgToplevel => const XdgTopLevelDevView(),
                SurfaceType.x11Surface => const X11SurfaceDevView(),
              }, */
                  Container(),
            ),
          ),
        ],
      ),
    );
  }
}

/* class XdgTopLevelDevView extends HookConsumerWidget {
  const XdgTopLevelDevView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceManager = ref.watch(surfaceManagerProvider);
    final topLevelList = surfaceManager.xdgTopLevelSurfaces;
    return ListView.separated(
      itemBuilder: (context, index) {
        final surfaceId = topLevelList[index];
        final surfaceState = ref.read(xdgSurfaceStateProvider(surfaceId));
        final properties = ref.read(windowPropertiesStateProvider(surfaceId));
        final matchedWindowId =
            ref.read(surfaceWindowMapProvider).get(surfaceId);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 500,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: $surfaceId'),
                    Text('Title: ${properties.title}'),
                    Text('AppId: ${properties.appId}'),
                    Text('Pid: ${properties.pid}'),
                    Text('Mapped: ${surfaceState.mapped}'),
                    Text('Committed: ${surfaceState.committed}'),
                    Text('Geometry: ${surfaceState.geometry}'),
                    Text('Matched Window: $matchedWindowId'),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 400,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: FittedBox(
                  child: DeferredPointerHandler(
                    child: SurfaceWidget(
                      surfaceId: surfaceId,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      separatorBuilder: (context, index) => const Divider(),
      itemCount: topLevelList.length,
    );
  }
} */

/* class X11SurfaceDevView extends HookConsumerWidget {
  const X11SurfaceDevView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceManager = ref.watch(surfaceManagerProvider);
    final x11SurfaceList = surfaceManager.x11Surfaces;
    return ListView.separated(
      itemBuilder: (context, index) {
        final x11SurfaceId = x11SurfaceList[index];
        final x11SurfaceState = ref.read(x11SurfaceStateProvider(x11SurfaceId));
        final properties = x11SurfaceState.surfaceId != null
            ? ref
                .read(windowPropertiesStateProvider(x11SurfaceState.surfaceId!))
            : const WindowProperties(appId: '');
        final matchedWindowId = x11SurfaceState.surfaceId != null
            ? ref.read(surfaceWindowMapProvider).get(x11SurfaceState.surfaceId!)
            : null;
        final metaWindowId =
            ref.read(metaWindowIdPerX11SurfaceIdProvider(x11SurfaceId));
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 500,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: $x11SurfaceId'),
                    Text('Title: ${properties.title}'),
                    Text('AppId: ${properties.appId}'),
                    Text('Pid: ${properties.pid}'),
                    Text('Mapped: ${x11SurfaceState.mapped}'),
                    Text('Geometry: ${x11SurfaceState.geometry}'),
                    Text('Associated WlSurface: ${x11SurfaceState.surfaceId}'),
                    Text(
                      'Override Redirect: ${x11SurfaceState.overrideRedirect}',
                    ),
                    Text('Parent: ${x11SurfaceState.parent}'),
                    Text('Children: ${x11SurfaceState.children.length}'),
                    Text('Matched Window: $matchedWindowId'),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 400,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: FittedBox(
                  child: metaWindowId != null
                      ? MetaSurfaceWidget(
                          metaWindowId: metaWindowId,
                          decorated: false,
                        )
                      : null,
                ),
              ),
            ),
          ],
        );
      },
      separatorBuilder: (context, index) => const Divider(),
      itemCount: x11SurfaceList.length,
    );
  }
} */

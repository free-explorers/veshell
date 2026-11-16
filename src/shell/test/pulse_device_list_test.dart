import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pulseaudio/pulseaudio.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_audio.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_sink_list.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_source_list.dart';

PulseAudioSink _sink(int index, String name, {double volume = 0.5}) =>
    PulseAudioSink(
      index: index,
      name: name,
      description: name,
      mute: false,
      volume: volume,
    );

PulseAudioSource _source(int index, String name) => PulseAudioSource(
  index: index,
  name: name,
  description: name,
  mute: false,
  volume: 0.5,
);

/// A sound server the test drives: it answers the initial lists when told
/// to and emits device events on demand.
class _FakeServer implements PulseAudioClient {
  final sinkChanged = StreamController<PulseAudioSink>.broadcast();
  final sinkRemoved = StreamController<int>.broadcast();
  final sourceChanged = StreamController<PulseAudioSource>.broadcast();
  final sourceRemoved = StreamController<int>.broadcast();
  final sinkList = Completer<List<PulseAudioSink>>();
  final sourceList = Completer<List<PulseAudioSource>>();

  @override
  Stream<PulseAudioSink> get onSinkChanged => sinkChanged.stream;
  @override
  Stream<int> get onSinkRemoved => sinkRemoved.stream;
  @override
  Stream<PulseAudioSource> get onSourceChanged => sourceChanged.stream;
  @override
  Stream<int> get onSourceRemoved => sourceRemoved.stream;
  @override
  Future<List<PulseAudioSink>> getSinkList() => sinkList.future;
  @override
  Future<List<PulseAudioSource>> getSourceList() => sourceList.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePulseClient extends PulseClient {
  _FakePulseClient(this.server);
  final _FakeServer server;

  @override
  Future<PulseAudioClient> build() async => server;
}

ProviderContainer _container(_FakeServer server) {
  final container = ProviderContainer(
    overrides: [
      pulseClientProvider.overrideWith(() => _FakePulseClient(server)),
    ],
  );
  addTearDown(container.dispose);
  final sinks = container.listen(pulseSinkListProvider, (_, _) {});
  addTearDown(sinks.close);
  final sources = container.listen(pulseSourceListProvider, (_, _) {});
  addTearDown(sources.close);
  return container;
}

List<String> _sinkNames(ProviderContainer container) => container
    .read(pulseSinkListProvider)
    .requireValue
    .map((sink) => sink.name)
    .toList();

List<String> _sourceNames(ProviderContainer container) => container
    .read(pulseSourceListProvider)
    .requireValue
    .map((source) => source.name)
    .toList();

void main() {
  test('a hot-plugged sink leaves the list when removed', () async {
    final server = _FakeServer();
    final container = _container(server);
    server.sinkList.complete([_sink(1, 'speaker')]);
    await pumpEventQueue();

    server.sinkChanged.add(_sink(80, 'headset'));
    await pumpEventQueue();
    expect(_sinkNames(container), ['speaker', 'headset']);

    server.sinkRemoved.add(80);
    await pumpEventQueue();
    expect(_sinkNames(container), ['speaker']);
  });

  test('a stale removal does not drop a sink that came back', () async {
    final server = _FakeServer();
    final container = _container(server);
    server.sinkList.complete([_sink(1, 'speaker')]);
    await pumpEventQueue();

    // The headset reappears under a new index before its old one is removed.
    server.sinkChanged
      ..add(_sink(80, 'headset'))
      ..add(_sink(85, 'headset'));
    server.sinkRemoved.add(80);
    await pumpEventQueue();
    expect(_sinkNames(container), ['speaker', 'headset']);

    server.sinkRemoved.add(85);
    await pumpEventQueue();
    expect(_sinkNames(container), ['speaker']);
  });

  test('events received while loading are not undone by the list', () async {
    final server = _FakeServer();
    final container = _container(server);
    await pumpEventQueue();

    server.sinkChanged.add(_sink(1, 'speaker', volume: 0.8));
    server.sinkRemoved.add(2);
    await pumpEventQueue();
    server.sinkList.complete([
      _sink(1, 'speaker', volume: 0.3),
      _sink(2, 'hdmi'),
    ]);
    await pumpEventQueue();

    final sinks = container.read(pulseSinkListProvider).requireValue;
    expect(sinks.map((sink) => sink.name), ['speaker']);
    expect(sinks.single.volume, 0.8);
  });

  test('a hot-plugged source leaves the list when removed', () async {
    final server = _FakeServer();
    final container = _container(server);
    server.sourceList.complete([_source(3, 'mic')]);
    await pumpEventQueue();

    server.sourceChanged
      ..add(_source(81, 'headset_mic'))
      ..add(_source(82, 'headset.monitor'));
    await pumpEventQueue();
    expect(_sourceNames(container), ['mic', 'headset_mic']);

    server.sourceRemoved
      ..add(81)
      ..add(82);
    await pumpEventQueue();
    expect(_sourceNames(container), ['mic']);
  });
}

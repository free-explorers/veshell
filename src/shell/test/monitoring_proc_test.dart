import 'package:flutter_test/flutter_test.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_parsing.dart';

void main() {
  group('parseProcStat', () {
    test('reads the aggregate line first, then each core', () {
      const contents = '''
cpu  100 0 50 850 0 0 0 0 0 0
cpu0 50 0 25 425 0 0 0 0 0 0
cpu1 50 0 25 425 0 0 0 0 0 0
intr 12345
ctxt 67890
''';

      final lines = parseProcStat(contents);

      expect(lines.map((line) => line.label), ['cpu', 'cpu0', 'cpu1']);
      expect(lines.first.total, 1000);
      expect(lines.first.idleTicks, 850);
      expect(lines[1].label, 'cpu0');
    });

    test('treats fields the kernel did not report as zero', () {
      // Kernels before guest/guest_nice stopped after `steal`.
      final lines = parseProcStat('cpu0 1 2 3 4 5 6 7');

      expect(lines, hasLength(1));
      expect(lines.first.tick(6), 7); // steal, the last field present
      expect(lines.first.tick(7), 0); // guest, absent on the older kernel
      expect(lines.first.total, 28);
    });

    test('skips non-cpu lines and malformed counters', () {
      final lines = parseProcStat('cpu 1 2 3\nbogus 1 2 3\ncpu0 1 x 3');

      expect(lines, hasLength(1));
      expect(lines.first.label, 'cpu');
    });
  });

  group('cpuUsagePercent', () {
    CpuLine line(List<int> ticks) => CpuLine(label: 'cpu', ticks: ticks);

    test('computes the busy fraction between two samples', () {
      // 1000 ticks elapsed, 950 of them idle.
      final previous = line([100, 0, 50, 850, 0, 0, 0, 0]);
      final now = line([150, 0, 50, 1800, 0, 0, 0, 0]);

      expect(cpuUsagePercent(previous, now), closeTo(5, 0.001));
    });

    test('reports a fully busy CPU', () {
      expect(
        cpuUsagePercent(
          line([100, 0, 0, 0, 0, 0, 0, 0]),
          line([200, 0, 0, 0, 0, 0, 0, 0]),
        ),
        closeTo(100, 0.001),
      );
    });

    test('reports an idle CPU', () {
      final previous = line([100, 0, 0, 900, 0, 0, 0, 0]);
      final now = line([100, 0, 0, 1000, 0, 0, 0, 0]);

      expect(cpuUsagePercent(previous, now), 0);
    });

    test('returns zero when the counters did not move', () {
      final same = line([100, 0, 0, 900, 0, 0, 0, 0]);

      expect(cpuUsagePercent(same, same), 0);
    });
  });

  group('parseMemInfo / memoryUsedKb', () {
    test('parses fields to kB and prefers MemAvailable', () {
      const contents = '''
MemTotal:       1000 kB
MemFree:         100 kB
MemAvailable:    400 kB
Buffers:          50 kB
Cached:          200 kB
SReclaimable:     30 kB
Shmem:            10 kB
HugePages_Total:   0
''';

      final info = parseMemInfo(contents);

      expect(info['MemTotal'], 1000);
      expect(info['MemAvailable'], 400);
      expect(info['HugePages_Total'], 0);
      expect(memoryUsedKb(info), 600);
      expect(memoryUsedPercent(info), 60);
    });

    test('falls back to the htop formula without MemAvailable', () {
      const contents = '''
MemTotal:       1000 kB
MemFree:         100 kB
Buffers:          50 kB
Cached:          200 kB
SReclaimable:     30 kB
Shmem:            10 kB
''';

      final info = parseMemInfo(contents);

      // 1000 - 100 - 50 - 200 - 30 + 10.
      expect(memoryUsedKb(info), 630);
      expect(memoryUsedPercent(info), 63);
    });

    test('returns zero without a total', () {
      expect(memoryUsedPercent(const {}), 0);
    });
  });

  group('parseProcPidStat', () {
    test('reads utime/stime from a plain command name', () {
      const line = '1234 (cat) R 1 2 3 4 5 6 7 8 9 10 1111 2222 0 0';

      final times = parseProcPidStat(line);

      expect(times, isNotNull);
      expect(times!.utime, 1111);
      expect(times.stime, 2222);
    });

    test('survives a command name containing spaces and parentheses', () {
      // The comm field may hold spaces and `)`, which naive splitting breaks.
      const line = '7 (my )app) S 1 2 3 4 5 6 7 8 9 10 42 24 0 0';

      final times = parseProcPidStat(line);

      expect(times, isNotNull);
      expect(times!.utime, 42);
      expect(times.stime, 24);
    });

    test('returns null when the numeric fields are missing', () {
      expect(parseProcPidStat('1234 (cat) R 1 2 3'), isNull);
      expect(parseProcPidStat('not a stat line'), isNull);
    });
  });

  test('parseProcPidStatmResidentPages reads the resident field', () {
    expect(parseProcPidStatmResidentPages('1000 250 100 1 0 200 0'), 250);
    expect(parseProcPidStatmResidentPages('1000'), isNull);
  });
}

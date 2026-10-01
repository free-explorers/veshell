# Monitoring

## Description

The Monitoring cards are the system-activity group of the [Overview](overview.md)
Helm. They report whole-machine load — CPU, memory, disk and, when hardware
exposes it, GPU — plus a per-process breakdown for the expandable cards.

Each card is an [`ExpandableCard`](../src/shell/lib/shared/widget/expandable_card.dart):
collapsed it shows the current value as a badge over a rolling line chart;
expanded it also lists the processes contributing to it, sorted by share.

The cards live in
`src/shell/lib/overview/helm/monitoring_panel/`, grouped by metric:

```
cpu_monitoring/
  model/       value and snapshot models
  provider/    aggregate sampler, per-process sampler, graph history
  widget/      the card
memory_monitoring/  ...
disk_monitoring/    ...
gpu_monitoring/     ... (AMD/amdgpu; see "GPU")
sampling/      shared /proc parsers, file helpers and the poller
widget/        MonitoringCard, MonitoringChart, ProcessMetricList
```

## Data sources

Everything is read directly from `/proc` and `/sys` on the shell side; no
privileged helper is involved.

| Metric | Source | Notes |
|---|---|---|
| CPU | `/proc/stat` | Aggregate `cpu` line for the badge; per-process `utime + stime` from `/proc/<pid>/stat` |
| Memory | `/proc/meminfo` | Used prefers `MemAvailable`; fallback is the `htop` formula |
| Per-process RSS | `/proc/<pid>/statm` | Resident pages × system page size |
| Disk | `universal_disk_space` (shells out to `df`) | Physical filesystems only, `/boot` hidden; rescanned every 5 s while the panel is open |
| GPU | `/sys/class/drm/card*/device/*` | Vendor-dependent, see below |

## Sampling lifecycle

The cards answer "was there a spike just now, or is this climbing?", so the
history has to be recent and continuous. The aggregate samplers therefore run
for the whole session.

- **Aggregate samplers are keep-alive and primed.** `CpuStatsState`,
  `MemoryStatsState` and `GpuStatsState` sample `/proc/stat`, `/proc/meminfo`
  and the GPU sysfs every 500 ms from startup (`main.dart` primes them), so the
  graph is already populated the first time the overview opens. Each tick reads
  a handful of small files.
- **Per-process samplers are bounded by the card.** The `/proc/<pid>` walk is
  the expensive part (hundreds of files); those providers are auto-disposed and
  run only while their card is expanded.
- **Graphs are ring buffers.** The CPU, memory and GPU charts keep the newest
  120 samples — about a minute at 500 ms. A sampler appends through `add()`, so
  the chart always ends at *now* and a recent spike or a rising curve is visible
  the moment the overview opens.
- **Disk is polled slower.** `DiskSpaceState` rescans every 5 s while the panel
  is open; a `df` subprocess is far more expensive than the `/proc` reads. Its
  last reading lives in the keep-alive `DiskSpaceCache`, so a reopened card
  shows it on the first frame while the next scan runs.

The poller (`sampling/proc_files.dart`) samples once immediately, so a freshly
opened card is populated before the first interval elapses, then schedules the
next tick only after the current sample completes — a slow scan never overlaps
the following one, and a transient read failure is logged and skipped instead
of killing the loop. Sampling stops for good once the returned cancel callback
runs, which the providers wire to `ref.onDispose`.

Per-process lists are sampled only while their card is expanded; the aggregate
badge and chart keep refreshing while collapsed.

## Per-process semantics

- **CPU** is the process's share of *whole-machine* CPU, matching the badge:
  `Δ(utime + stime) / Δ(total CPU ticks)`, so all processes together stay under
  100 % and a process pegged on every core approaches it.
- **Memory** is resident set size as a fraction of `MemTotal`. Pages shared
  between processes count for each of them, so the percentages may add up to
  more than 100 %; the list is a ranking, not a partition.

`/proc/<pid>/stat` is parsed by locating the fields after the *last* `)` of the
parenthesised command name, which may itself contain spaces and parentheses;
splitting the whole line by whitespace would shift `utime`/`stime`.

The lists drop kernel threads (no executable behind `/proc/<pid>/exe`) and rows
below 0.01 %, which keeps them focused on applications. Kernel threads can
still consume CPU, so a softirq or workqueue bottleneck is not visible in the
list; the aggregate trend is.

## Adding a metric

A new metric is a `cpu_monitoring/`-shaped folder plus a card contributed to
`monitoringSection` in `widget/monitoring_panel.dart`. Reuse
`sampling/proc_files.dart` (`startPolling`, `readProcFile`, `listProcessIds`)
and the pure parsers in `sampling/proc_parsing.dart`, and build the card from
the shared `MonitoringCard` / `MonitoringChart` / `ProcessMetricList`. A card
whose hardware is absent should be omitted from the section entirely, the way
the battery card is gated on `anyUpowerDeviceProvider`.

### GPU

`reader/gpu_device.dart` detects the card and picks a vendor reader; the card
is omitted when no supported GPU is found, like the battery card. Each sample
reads what the vendor exposes:

| Vendor | Source | Notes |
|---|---|---|
| AMD (amdgpu) | `device/gpu_busy_percent`, `mem_info_vram_*`, `mem_info_gtt_*`, hwmon | True utilisation, VRAM and GTT |
| Intel (i915/xe) | `gt*_freq_mhz` / `device/tile0/gt0/freq0/*`, hwmon | No root-free busy counter: the load is the RPS frequency relative to min/max, a **proxy**, not engine utilisation. No dedicated VRAM |
| NVIDIA | NVML (`libnvidia-ml`) | Utilisation, VRAM, temperature, power and clocks; a missing library or symbol means no card |

`reader/gpu_parsing.dart` holds the vendor-neutral unit conversions and
`reader/intel.dart` the frequency proxy; both are unit-tested. `reader/nvidia.dart`
binds the NVML subset through `dart:ffi` and is the only native binding.

The choice of card mirrors the compositor's own in `drm_backend.rs`: an explicit
`DRM_DEVICE` override wins (a `cardN` or `renderDN` path), otherwise the boot
VGA (`device/boot_vga`), otherwise the lowest-numbered card. For NVIDIA, NVML
device `0` is used (multi-NVIDIA selection is not yet wired). The selected
card's PCI address then filters per-process clients, so another GPU's clients
are never attributed to it.

The GPU chart overlays device load and VRAM usage on the same `0..100` axis and
over the same window (load as the filled area, VRAM as the stroked line). There
is no legend; instead the VRAM value in the expanded details is drawn in the
line's color. The VRAM series and row are omitted for cards without dedicated
memory (Intel), so only the load line remains. `MonitoringChart` takes a list of
`MonitoringSeries`, so the CPU and memory cards keep their single filled line
and only the GPU card can draw a second.

Expanding the card lists the processes using the GPU (`reader/process_gpu.dart`):
`/proc/<pid>/fd` is scanned for descriptors pointing at `/dev/dri/` before
their `fdinfo` is read, and fds sharing a `drm-client-id` are counted once. The
per-process figure is the change in total `drm-engine-*` nanoseconds over the
interval, so a process using several engines at once can exceed 100%. The
`drm-memory-*` regions are parsed but only the device totals are displayed.

Not yet covered:

- **Per-process GPU memory** is parsed from `fdinfo` but not yet shown; the
  card lists engine usage only.
- Intel load is a frequency proxy — a softirq or blitter-only workload may not
  move it.
- Multi-NVIDIA selection; NVML device `0` is hard-coded.

## Testing

The parsers, the percentage math, the history ring buffer and the poller are
covered by unit tests (`test/monitoring_proc_test.dart`,
`test/monitoring_chart_test.dart`, `test/monitoring_sampling_test.dart`) with
`/proc` fixtures, so no live system state is needed.

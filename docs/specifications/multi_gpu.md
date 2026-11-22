# Multi-GPU

## Description

On the DRM backend, Veshell drives the outputs of every GPU of the seat: an
external monitor wired to the discrete GPU of a hybrid laptop, or monitors
spread over an iGPU and a dGPU, all light up.

One GPU is the **render GPU**. Flutter renders on it, and every output is
composited on it, whatever GPU drives the output. The other GPUs only scan
out.

## Choosing the render GPU

- By default the render GPU is the one driving a connected built-in panel
  (eDP, LVDS or DSI): the panel is then composited without a copy between
  GPUs, even when the firmware booted on a discrete GPU that only drives the
  external ports.
- Without a connected built-in panel (a desktop, a closed lid at startup), it
  is the seat's boot GPU (`boot_vga`).
- `DRM_DEVICE` (a `/dev/dri/card*` or `/dev/dri/renderD*` path) names another
  one. It only picks where rendering happens: the outputs of every GPU are
  driven regardless. An Optimus laptop can render on the dGPU, which has no
  connectors, and display through the iGPU.

The render GPU is required: if it cannot be opened, the session does not
start. Any other GPU that fails to open is skipped, and the session goes on
without its outputs.

## Compositing an output of another GPU

The backend uses Smithay's `GpuManager`: one GLES renderer per GPU, and a
`MultiRenderer` per output, from the render GPU to the output's GPU.

- The output's swapchain is allocated on its own GPU, in the formats that GPU
  renders to, as with a single GPU.
- The composite is rendered on the render GPU into an offscreen buffer, then
  handed to the output's GPU: as a dmabuf when both GPUs share a format and
  modifier (often only `LINEAR` across vendors), or as a copy through memory
  otherwise. Only the composite's damage is copied.
- The NVIDIA proprietary driver cannot render into a `LINEAR` buffer (it imports
  one for sampling only) and no other GPU reads its own tilings: when it is the
  render GPU, the outputs of another GPU always go through memory. The copy is
  synchronous and costs the main thread a few milliseconds per changed frame,
  as with niri and Smithay's `MultiRenderer` in general. An iGPU rendering for
  an output of an NVIDIA GPU shares `LINEAR` buffers instead.
- The 10-bit output format is `ABGR2101010` only: the composite of another
  GPU's output is rendered in the output's format, and the NVIDIA driver
  renders 10-bit only as `XB30`/`AB30`.
- When the flip cannot wait on the composite's fence (the driver takes no
  in-fence, or the fence cannot be exported, as after a copy), the composite is
  waited for before the flip is queued.
- The Flutter frame lives on the render GPU. Its element is drawn through the
  render GPU's own GLES frame (`VeshellRenderer`), on every output.

## Client buffers

- The default dmabuf feedback names the render GPU: clients allocate buffers
  the compositing GPU can read, and every client dmabuf is imported there.
- Only an output of the render GPU sends a game the scanout tranche (see
  [Gaming mode](gaming_mode.md)). A client buffer is never scanned out
  directly by another GPU: its framebuffer exporter only accepts buffers of
  its own device, so those buffers are composited.

## Hotplug

- A GPU that appears later is opened and its connectors are scanned, like at
  startup.
- A GPU that goes away loses its outputs and is removed from the GPU manager.
  The render GPU cannot be replaced while the session runs: its removal is
  logged and nothing else changes.

## Pacing

Each GPU renders its outputs on its own fastest CRTC's vblank. Flutter's vsync
comes from the single fastest output, whatever its GPU (see
[Surface pacing](surface_pacing.md)).

The software frame cap (llvmpipe, swrast) applies when the render GPU or the
output's GPU rasterizes in software.

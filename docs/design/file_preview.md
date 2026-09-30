# Universal file preview from the overview — design notes

Status: **investigation, not implemented.** Branch `feat/file-explorer`.
Companion to
[`file_explorer_ephemeral_launch.md`](file_explorer_ephemeral_launch.md); the
explorer contract lives in
[`specifications/file_explorer.md`](../specifications/file_explorer.md).

## Goal

Preview **any** file inline in the overview, without launching an external
application: text, images, video, audio, PDF, office documents, archives,
fonts, binary blobs and directories.

## Where the preview lives

The Files pane is the entry point; the preview is driven by the current
selection. Three placements, mirroring Helm's responsive approach
(`lib/overview/helm/widget/helm.dart`):

1. **Split pane** — list on the left, preview on the right. Best on the wide
   overview surface.
2. **Full-pane** — preview replaces the list with a back action (Android Files
   style). Best when narrow.
3. **Overlay card** — a floating preview over the list.

Recommendation: split when wide, full-pane when narrow. A single click selects
and previews; a second action (double-click / Enter) hands the file to its
handler (the [ephemeral-launch](file_explorer_ephemeral_launch.md) path).

## What "universal" means — the fallback chain

Nothing should be a dead end. Resolution order per file:

raster image → SVG → PDF / office (rasterised) → video poster → audio metadata →
text → archive listing → font sample → binary hex → **metadata + "Open with…"**.

The last step is the terminal fallback for every file type.

## Architecture

A shared module `lib/file_preview/` (reusable beyond the explorer), following
the usual `model/ provider/ widget/` split.

- `PreviewKind` — `text`, `image`, `svg`, `pdf`, `office`, `video`, `audio`,
  `archive`, `font`, `binary`, `directory`, `unsupported`.
- `FilePreview` — a Freezed union carrying each kind's payload
  (`TextPreview`, `ImagePreview`, `VideoPreview`, `AudioPreview`, …).
- `previewKindProvider(path)` — classify by MIME (`xdg-mime query filetype`,
  extension fallback).
- `filePreviewProvider(path)` — `AsyncValue<FilePreview>`, `autoDispose`,
  cancelled when the selection changes.
- Per-kind loaders; heavy ones shell out and cache.
- `FilePreviewView` — one widget that switches on the union.

## Per-type backends

`xdg-mime`/`xdg-open` are already relied on in `file_opener.dart`, so the same
"system tool as an aid" stance applies here.

| Category | Detect (MIME) | Backend | Rendered as |
|---|---|---|---|
| Text / code / config / csv / md | `text/*`, extension | `dart:io` read, cap ~2 MB, NUL sniff, `utf8.decode(allowMalformed)`, in an isolate | `SelectableText`, monospace, scroll |
| Raster image | `image/png,jpeg,gif,webp,bmp` | Flutter's built-in codecs | `Image.file` with `cacheWidth/Height`; animated GIF/WebP free |
| SVG | `image/svg+xml` | `flutter_svg` (already a dependency) | `SvgPicture.file` |
| PDF | `application/pdf` | poppler `pdftoppm`/`pdftocairo` (present) → PNG pages in cache | page images / page view |
| Office | ooxml/odf | `soffice --headless --convert-to pdf` (present), lazy | PDF path |
| Video | `video/*` | `ffprobe` metadata + `ffmpeg` poster frame (present) | poster image + metadata |
| Audio | `audio/*` | `ffprobe` metadata + `ffmpeg` embedded cover | cover image + metadata |
| Archive | zip/tar/gz/… | `unzip -l` / `tar -tf` / `7z l` | entry list |
| Font | font/* | Flutter `FontLoader` sample | sample text |
| Binary / unknown | anything else | read first bytes | metadata + hex dump |
| Directory | `inode/directory` | explorer listing | the list |

## Video / audio playback — the hard part

Flutter has no built-in video playback on Linux and the official `video_player`
has no Linux desktop implementation. Two viable paths:

**A. Rust + GStreamer → external texture (architecture-aligned).** The
compositor already registers external textures
(`FlutterEngine::register_external_texture`,
`mark_external_texture_frame_available` in
`src/embedder/flutter_engine/mod.rs`) and creates texture ids in
`src/embedder/state.rs`; Dart renders them with `Texture(textureId:)`
(`lib/wayland/widget/surface.dart`). The Flutter Linux embedder also exposes
`FlPixelBufferTexture` (CPU RGBA) in
`src/shell/linux/flutter/ephemeral/flutter_linux/`. GStreamer is already a Rust
dependency (`gstreamer 0.24.5`, used for encoding in
`src/embedder/capture/recording.rs`). This gives full control — decode, audio
sink, seek, sync — but is a real project.

**B. A Flutter plugin (`media_kit` / libmpv).** Fastest to try, but adds a
native dependency and a plugin that must register textures in this custom
embedder; needs a spike to validate.

Recommendation: ship the **poster frame + metadata** first and treat in-shell
playback as its own milestone (spike B, fall back to A).

## Caching and performance

- Derived artifacts (posters, PDF pages, converted office PDFs) cached under
  `$XDG_CACHE_HOME/veshell/preview/<hash(path, mtime, size, recipe)>`.
- Read caps and tool timeouts; kill external tools when the selection changes.
- Debounce selection; hash/decode text off the UI isolate.
- LRU eviction and cleanup at shell start.

## Security and robustness

- Treat every file as data; never execute it.
- Bound source reads and external-tool runtime; quote/escape paths.
- Malformed or unsupported input → an error state with "Open with…", never a
  crash or a hung shell.

## Phasing

1. **Framework + pure-Flutter types** — module, `FilePreview` union, resolver,
   renderer; text, raster image, SVG, binary hex, metadata fallback.
2. **Rasterising backends** — PDF via poppler, video poster / audio metadata
   via ffmpeg, artifact caching.
3. **Playback + documents** — in-shell video/audio (spike), office via
   LibreOffice, archive listing, font sample.

## Open questions

- Placement: split pane vs full-pane vs overlay (or responsive all three)?
- Preview on selection, or only on an explicit action?
- Syntax highlighting / line numbers for text — worth a dependency?
- Playback engine: Rust GStreamer versus a Flutter plugin?
- Is a full LibreOffice conversion acceptable for office previews?
- Should previews also be what an ephemeral window shows, or stay inline?

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

## Where the preview lives (decided)

The preview takes over the **`OverviewContent` region** — the exact slot that
holds the Helm dashboard and the focused ephemeral window
(`lib/overview/widget/overview_content.dart`). The Files list stays in the left
`SearchEngine` column, so the overview becomes list-on-the-left,
preview-on-the-right without any new layout.

Precedence in that slot:

1. a **selected file** → preview;
2. else a focused **ephemeral window** → its surface;
3. else the **Helm** dashboard.

Selection state belongs to the screen's `Overview` (a `DirectoryPath?`
selection, mirroring `focusedWindowId`), set by the Files pane and read by
`OverviewContent`, so other producers (search results, notifications) can drive
the same preview later. Selecting a directory keeps navigating; leaving Files
mode or clearing the selection restores the previous occupant.

Interaction (decided): a single click **selects and previews** any entry — a
file previews, a directory highlights (with a folder summary in the slot); a
double click **opens** — a file through its handler (the
[ephemeral-launch](file_explorer_ephemeral_launch.md) path), a directory by
entering it. `ArrowUp`/`ArrowDown` move the selection and `Enter` opens, so the
keyboard matches the double click.

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

## Making it instant (performance)

Selection must feel instantaneous. The preview slot already exists, so there is
no layout work — only content. Rules:

- **Classify by extension first**, never spawn a process on the hot path.
  `xdg-mime` is a fallback only for unknown extensions (a spawn is 10–30 ms).
- **Two-phase render**: keep the previous preview visible (or show a lightweight
  skeleton) and swap content in when ready, so selection never blocks.
- **Cache decoded images**: a stable `FileImage` keyed by `path + mtime`, decoded
  at display size (`cacheWidth`/`cacheHeight`), plus `precacheImage` for the
  selected file and its neighbours.
- **Warm on listing**: prefetch bounded, idle-time metadata/thumbnails for
  visible rows (debounced) so the first selection is already hot.
- **Text**: read a capped prefix (~256 KB) for the instant view and continue in
  the background; decode off the UI isolate.
- **Derived artifacts** (posters, PDF pages, converted office PDFs) cached on
  disk under `$XDG_CACHE_HOME/veshell/preview/<hash(path, mtime, size, recipe)>`,
  generated asynchronously with a spinner and reused instantly afterwards.
- **Cancel and debounce** on rapid selection changes (arrow keys): compare a
  path token, drop stale results, kill in-flight external tools.
- **LRU eviction** and cleanup at shell start.

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

## Keyboard and focus (mechanics)

The overview's [keyboard contract](../specifications/overview.md#keyboard) is
`Tab`/`Shift+Tab` to move the selection, `Space`/`Enter` to open, and
`Super+Tab`/`Super+Shift+Tab` to switch search modes. Implementation notes:

- The shortcuts are declared **locally in the overview subtree** with a
  `Shortcuts` widget, so they win over the global `VeshellShortcutManager`
  (`lib/shortcut_manager/widget/shortcut_manager.dart`) and are not forwarded to
  clients.
- `Super+Tab` must not toggle the overview. `_ShortcutManager` clears its
  "Super pressed alone" flag when it sees another key go down — but a locally
  consumed chord stops propagation, so the manager may never see the `Tab` and
  would still toggle when Super is released. Its sole-Super detection must be
  made robust (listen through `HardwareKeyboard`, or handle the chord in the
  manager) rather than rely on `handleKeypress` seeing every key.
- Client surfaces deliberately do **not** consume `Tab`/`Space`/`Enter`/arrows:
  `SurfaceFocus` maps them to an action with `consumesKey => false`
  (`lib/wayland/widget/surface/surface_focus.dart`) so the Wayland client
  receives them. The overview's own bindings must consume them
  (default `consumesKey => true`) while the overview has focus.
- `Space` versus typing a space: bind `Space` only while the result list is
  focused, so the input still types spaces. The first `Tab` hands focus to the
  list, and a printable key hands it back to the input (type-to-search).

## Open questions

- Syntax highlighting / line numbers for text — worth a dependency?
- Playback engine: Rust GStreamer versus a Flutter plugin?
- Is a full LibreOffice conversion acceptable for office previews?
- Prefetch aggressiveness: how much to warm without wasting I/O?
- Does the preview slot also get used when a file is selected outside the Files
  pane (search results, notifications)?
- Do arrow keys stay as a secondary navigation, or are `Tab`/`Shift+Tab` the
  only bindings?

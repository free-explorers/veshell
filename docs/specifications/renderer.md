# Renderer

## Description

The shell is drawn by the Flutter engine's **Impeller** renderer, on GLES.
**Skia**, the engine's previous renderer, stays available as a fallback for a
driver Impeller renders wrong on, or not at all.

## Choosing the renderer

`VESHELL_RENDERER` in the compositor's environment, read once at startup:

- unset, empty or `impeller`: Impeller, with SDF antialiasing
  (`--enable-impeller --impeller-use-sdfs`);
- `skia`: Skia;
- anything else: Impeller, and a warning in the log.

The choice is manual. When Impeller cannot create its context, the engine
reports no error to the embedder and renders nothing, so there is no failure to
fall back on automatically. The variable has to be in the environment that
starts Veshell (the session's launcher, `environment.d`): the user's
environment variables in Settings are applied only once the shell runs.

## What differs

- **Antialiasing.** Impeller antialiases paths and clips through
  multisampling: the view's render target takes the samples the
  `display.antialiasing` setting asks for. Skia antialiases analytically: its
  render target keeps a single sample and the setting has no effect.
- Everything else is shared: the view targets and their partial repaint,
  client windows handed to the engine as GL textures, and the compositing of
  Flutter's frame.

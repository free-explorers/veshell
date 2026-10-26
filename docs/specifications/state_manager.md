# StateManager

## Description

The StateManager keeps track of the shell's state and saves it so the layout and
the user's work can be restored on the next start.

## What is stored

State lives under `$VESHELL_CONFIG_DIR/persistence`, one JSON file per key:

| Key | Contents |
| --- | --- |
| `WindowManager` | the set of persistent tiles |
| `persistent_window_<uuid>` | a tile's application identity, title, display mode, custom exec, and resume context |
| `workspace_<id>` | a workspace's tiles and selection |
| `ScreenManager`, `screen_<id>` | screens and their workspaces |
| `MonitorManager`, `MonitorConfigurationState(<id>)` | monitor/screen configuration |
| `NotificationManager` | notifications |

This includes personal data: window titles, working directories and document
paths. The directory is created with mode `0700` and every file with mode
`0600`, so other local users cannot read it. Nothing is encrypted at rest.

## Schema and migrations

Every file is wrapped in an envelope:

```json
{
  "$veshell": { "store": "persistent_window", "version": 1 },
  "data": { "...": "the model JSON" }
}
```

The `store` selects a migration chain. A file without the envelope is treated as
version `0` and migrated on load, then rewritten with the current envelope, so
adding versioning does not drop existing tiles or workspaces. The persistent
window store is currently version `2`: version `1` files gain the resume-context
fields before the model decoder runs.

When a persisted model changes shape:

1. bump `currentVersion` for its store in
   `lib/shared/model/persistence_schema.dart`;
2. add the `oldVersion -> oldVersion + 1` migration to the store's chain;
3. keep the migration pure and limited to the raw JSON map, before the model
   decoder runs.

A missing migration step is not treated as a no-op.

If a file cannot be loaded — malformed JSON, an unknown store, or a version
newer than this build understands — it is moved to
`persistence/quarantine/<key>.<timestamp>.json` instead of being deleted, and
the tile/workspace starts from a clean state. The reason and every migrated or
quarantined file are logged under the `Persistence` logger at startup:

```
[Persistence] Loaded 12 persisted file(s) from ...: WindowManager, ... (migrated 1, quarantined 0)
[Persistence] Migrated persistent_window_... from version 0 to 1
[Persistence] Quarantined workspace_... to ...: invalid JSON for ...
```

Older shell builds cannot read the envelope. Downgrading after the new format
has been written is not supported; the newer-version quarantine protects against
silent data loss, not against downgrade.

## Writing

State writes are debounced per file (~100 ms) and atomic: content is written to
`<key>.json.tmp`, flushed, restricted to `0600`, then renamed over the target.
A killed process therefore leaves either the old complete file or the new one,
never a partial file. Stale `.tmp` files are removed on the next startup.

`flushPendingWrites()` promotes every debounced snapshot into the same per-path
write chain and waits for the chains to drain, with a short timeout. It is called:

- by the shell's logout/reboot/shutdown controls, before asking logind;
- on logind's `PrepareForShutdown` signal, so an external `systemctl reboot`
  also flushes;
- before suspend/hibernate.

Flush and normal writes cannot interleave into a corrupt file because both go
through the per-path chain.

## Teardown

While the session is leaving, applications are terminated and report their
windows gone. Those transient removals must not clear the state the next login
should resume. `SessionGuard` latches a leaving flag before the flush; window
state writers stop adopting titles/pids and resume-context updates from
teardown events. Only the runtime window reference is cleared, so a cancelled
shutdown does not leave a tile pointing at a destroyed window. The saved title,
working directory and resume context are preserved.

## Clearing state

- Everything: remove `$VESHELL_CONFIG_DIR/persistence`.
- One tile: remove `persistence/persistent_window_<uuid>.json` while the shell
  is not running, and the matching id from the workspace files; removing the
  tile from the UI is the supported path.
- Inspect quarantined data: `persistence/quarantine/`; the files are plain JSON
  and can be deleted once no longer needed.

The persistence backend is intentionally still JSON files; encryption and
cross-machine sync are out of scope.

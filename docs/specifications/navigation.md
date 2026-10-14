# Navigation and actions

## Description

Shell navigation is expressed once, in the abstract, and every context decides
what a direction means for the thing it owns. A physical key resolves to a
generic **intent**; the focused context supplies the behaviour. The same
`Super+W/S/A/D` family therefore moves workspaces at the screen, tileables in a
workspace and result rows in the overview, without three separate binding
tables shadowing one another.

An action may also carry **several bindings** (`Super+W` *and* `Super+Up`), so a
single action can be reached from more than one key. The two ideas compose: the
binding model is generic, and the intents are contextual.

## Split

| Concern | Owner |
| --- | --- |
| Global key chords and their resolution to intents | Shell (`hotkeys_setting`, `hotkeys_activator`, `VeshellShortcutManager`) |
| What an intent means at the screen, in a workspace, in the overview | Shell widgets (`ScreenWidget`, `WorkspaceWidget`, `OverviewShortcuts`, `SearchEngine`) |
| Forwarding a chord that no focused context handled to the client | Compositor (`keyboard`) |
| Key repetition | Compositor repeater for the shell; clients repeat themselves (see [Keyboard](keyboard.md)) |

## Intent model

`shortcut_manager/model/navigation_intents.dart` defines the shell vocabulary,
and activation/dismissal reuse Flutter's own intents so the shell's hotkeys
drive the framework focus system:

| Intent | Meaning |
| --- | --- |
| `NavigateIntent(direction)` | Move the selection/focus one step in `direction` |
| `MoveIntent(direction)` | left/right reorder the selected tileable; up/down send it to the workspace above/below |
| `CloseIntent` | Close the focused item (tileable) |
| `CycleIntent(forward:)` | Move to the next/previous item of a context-owned set |
| Flutter `ActivateIntent` | Activate the focused control / the current selection |
| Flutter `DismissIntent` | Dismiss the topmost overlay (dialog, menu, drawer) or the overview |

`direction` is one of `up`, `down`, `left`, `right`.

Directional movement deliberately stays a shell intent rather than Flutter's
`DirectionalFocusIntent`: a text field registers its own handler for the latter
(to keep the arrows for cursor movement), which would shadow the
workspace/tileable handlers whenever the launcher search field holds focus.
Focus-based contexts handle `NavigateIntent` by calling
`FocusNode.focusInDirection`, so the traversal itself is still the framework's.

## Contexts

Each context registers handlers only for the directions it owns and forwards
the rest to its enclosing context with `Actions.maybeInvoke` on a context above
its own `Actions` (the widget's build context). Only the focused context's
handlers run, because a resolved intent is dispatched from
`primaryFocus.context` upwards.

| Context | `NavigateIntent` | `MoveIntent` | `ActivateIntent` | `DismissIntent` | `CloseIntent` | `CycleIntent` |
| --- | --- | --- | --- | --- | --- | --- |
| **Screen** | up/down select the workspace | up/down send the selected tile to the workspace above/below and follow it | — | — | — | — |
| **Workspace** | left/right select the tileable; up/down forwarded to the screen | left/right reorder the tileable; up/down forwarded | — | — | close the focused tileable | — |
| **Search field** (`SearchEngine`) | down hands the keyboard to the result list; left/right move across the panes | — | activate the current result | — | — | — |
| **Result list** (applications / files) | up/down move the roving selection cursor; up on the first row returns to the field; left/right move across the panes | — | activate the selected row | — | — | — |
| **Content pane / Helm** | framework traversal (`focusInDirection`) | — | activate the focused control | — | — | — |
| **Overview fallback** | up/down move the selection; left/right move focus | — | — | hide the overview | — | cycle the search mode |

The overview is a sibling of the workspace panes and takes focus when open, so
its handlers win over the screen's while it is displayed. The workspace nests
inside the screen, so its horizontal handlers win and its vertical ones
delegate upwards.

`Backspace` is bound inside the file pane to `ParentIntent` (go up a directory),
so it goes up when a result row has focus but stays with the search field for
editing text. Activation from the search field uses the current selection, or
the **first** result when nothing is selected, so a query can be accepted with
`Activate` straight away.

## Focus

The overview is driven by Flutter's focus system so its widgets are reachable
by keyboard **and** assistive technology:

- The search field keeps the keyboard while filtering. `Super+Down` (or a
  click) hands it to the result list — the overview behaves like a combobox;
  `Super+Up` on the first result hands it back. A click focuses the clicked row
  too, so the pointer and the keyboard agree on the selection.
- Each result row owns a `FocusNode` (roving tab index): the selection cursor
  and the focus move together, so a screen reader follows the selection, while
  activation (`ActivateIntent`, i.e. `Enter`) acts on the focused row. The row's
  fill is a *focus* effect, not a persistent selection tint: moving the keyboard
  to the content pane clears it, so leaving the list is visible.
- The content pane is made of focusable Material widgets (the Helm's buttons,
  switches, sliders, list tiles, notification list). Directional navigation
  there delegates to `FocusNode.focusInDirection`, so the framework walks the
  Helm with the same chords; `RequestFocusAction`'s callback scrolls the
  focused control into view. The Helm groups each column
  (`FocusTraversalGroup`) so `Tab` walks a column and the directional keys cross
  between columns.
- The settings tree uses native focusable `ListTile`s.
- `Escape` resolves through the framework's `DismissIntent` binding (already
  installed by `MaterialApp`), so a dialog, menu or drawer opened above the
  overview wins before the overview hides.

## Bindings

`keyboard.hotkeys` maps an action id to a **list** of key chords:

```json
"navigation": {
  "up":     ["super+w", "super+arrowUp"],
  "down":   ["super+s", "super+arrowDown"],
  "left":   ["super+a", "super+arrowLeft"],
  "right":  ["super+d", "super+arrowRight"],
  "moveUp": ["super+shift+w", "super+shift+arrowUp"],
  "activate": ["enter", "numpadEnter"],
  "close":  ["super+q"]
}
```

Shipped defaults:

| Key | Intent |
| --- | --- |
| `Super+W` / `Super+Up` | Navigate up |
| `Super+S` / `Super+Down` | Navigate down |
| `Super+A` / `Super+Left` | Navigate left |
| `Super+D` / `Super+Right` | Navigate right |
| `Super+Shift+W/S/A/D` (+ arrows) | left/right reorder the tileable; up/down send it to the workspace above/below and follow it there |
| `Enter` / `Numpad Enter` | Activate |
| `Super+Q` | Close |
| `Super+Tab` / `Super+Shift+Tab` | Cycle the overview search mode |
| `Escape` | Dismiss (overview) |

`Escape` and `Super+Tab` are overview-only intents and stay local to the
overview; the rest are global settings.

### Plain keys stay safe

A chord is only consumed when an **enabled action for its intent exists in the
focused context's ancestry**. The `ActivateIntent` handler is therefore
registered only by the search pane (`SearchEngine`) and the result lists, so
`Enter` acts there but is ignored — and forwarded to the focused client —
everywhere else, and never steals `Enter` from a focused client surface or an
unrelated text field. `DismissIntent` is registered by the overview, so
`Escape` hides it, but a dialog or menu opened above it consumes the key first.
`Super+Tab` is registered above both overview panes, so it keeps acting no
matter which part of the overview holds focus.

## Properties

`Map<String actionId, List<LogicalKeySet>>` hotkeys.

## Invariants

- A physical chord has one meaning per context; the same chord means the same
  direction at every level, and the level decides the target.
- A context handles only the directions it owns and forwards the rest to its
  enclosing context; it never silently swallows a direction it cannot act on.
- An action may carry any number of bindings; every binding resolves to the
  same intent.
- A stored single-string binding from before the list form still parses as a
  one-element list, and an empty or malformed entry is skipped rather than
  becoming an activator.
- A binding is only consumed where a handler for its intent is in the focused
  context's ancestry; otherwise the chord falls through to the focused client.
- Renamed navigation action ids fall back to their pre-standardisation key so a
  user's existing override is not dropped.
- The result list's selection cursor and the framework focus stay in step:
  handing focus to the list selects its row, and moving the cursor updates the
  highlight and the preview in one place.
- Activation and dismissal use Flutter's `ActivateIntent` / `DismissIntent`, so
  the shell's hotkeys drive focused framework widgets (buttons, list tiles,
  dialogs, menus) and assistive technology sees the same focus path.

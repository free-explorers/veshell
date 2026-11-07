# PersistentApplicationLauncher

## Description

a PersistentApplicationLauncher is a [Tileable](tileable.md) which is used to start new application opened as [PersistentWindow](persistent_window.md) that persist in the layout even when it's closed.

## Layout

- The search field sits above the application grid and grows to at most
  720 px. While it holds text, a clear button empties it.
- With an empty search, the most used applications sit in a card of their own:
  one row, as many as fit, above the card of the alphabetical list. It is
  hidden while searching.
- The whole launcher tile scrolls, not the list card: browsing scrolls the
  search field and the most used away and gives the list the tile's height.
  The list card always reaches the bottom of the tile, so it keeps its height
  while a search narrows it. The search field keeps the keyboard while out of
  view; typing, clearing or launching scrolls back to the top, and the
  keyboard selection is scrolled into view as it moves.
- "Most used" is a frecency: launches from this launcher or the overview
  search each add one to an application's weight, which halves every week, so
  a habit that stops fades out within weeks. The weights are remembered across
  sessions.
- While searching, the part of each name the search matched is shown in bold.
  A search that matches nothing says so instead of leaving the grid empty.

## Opening

Launching an application creates its tile at once, in the launcher's place,
and selects it. The launcher moves aside to the next slot, under the new tile
(even when a single tile is shown, where it slides out of view), and is never
shown twice: it holds still while the launched item lifts out of it as a card,
then slides away, arriving as the card lands.
The tile opens with the launched item morphing into its
[placeholder](persistent_window.md), from where the item was:

- the item, as a card of the launcher's card color, grows into the
  placeholder's centered card (its rect, corners and translucent color);
- the item's icon and label travel to the placeholder's icon and title, the
  label growing into the title;
- the rest of the card's content fades in at its place;
- behind it, the placeholder's blurred icon backdrop fades in early, in the
  first quarter of the morph, hiding the launcher as it slides away;
- the item detaches from the launcher: its button there is hidden, and a new
  one fades in at its place as the card lands. Only the section it was
  launched from (the most used row or the list) replaces it; its copy in the
  other section stays.

The tile's placeholder is mounted from the start (it holds the keyboard) but
only painted once the morph, which ends exactly as it looks, is over. With
animations disabled, the tile opens without it.

## Keyboard

The launcher's search box autofocuses while the launcher is shown, and keeps the
keyboard while the launcher is used:

- Typing filters the applications, case-insensitively: names starting with the
  search come first, then names whose words start with every word of the
  search, then matches through the entries' `Keywords`. Within each of these,
  the most used applications come first.
- One application is selected: the first one, until the selection is moved.
  `Up`/`Down` move it by a row, crossing between the most-used card and the
  grid; `Left`/`Right` move it by one
  application once the caret is at that end of the search text (so the text
  stays editable). The selection is outlined only once the keyboard is in use
  (a search typed or an arrow pressed).
- `Enter` launches the selected application, so a search can be accepted
  without reaching for the mouse (an empty result list does nothing).

Launching an application, by keyboard or click, clears the search.

## Properties


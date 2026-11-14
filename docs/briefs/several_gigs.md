# Brief: several gigs at once

Written 2026-11-14 by Opus, for the builder agent (Sonnet). Manny is away; the calls marked
[Leaning] below are defaults to put to him.

## What and why

The core loop is "undock, chain gigs, and dock again or die trying" (DESIGN.md "Core loop", Locked),
and "Gigs" said one active gig at a time only "to start; chaining several ... comes once the first gig
plays well". Manny said gigs feel great, so the pilot can now hold up to three gigs at once, taken from
any boards they reach, flown in whatever order they like. The tracker shows them all, one in full; the
boards show how many are held. Manny wants flying to take skill, so the game doesn't plan the chain for
them: each gig's own requirements are checked, and the route through them is the pilot's problem.

Today (from the explorer): one slot, `Agency.active: Gig` (scripts/gig/agency.gd:35), read by
`requirements()` (the "ONE GIG AT A TIME" row, :178), `accept()` (:200), `options()` (:225),
`_physics_process()` (:275), `_deliver()`/`_pay()` (:330-346), `pilot_lost()`/`_on_ship_lost()`
(:362-382), the survey functions (:385-430), and `save_state()`/`restore_state()` (:99-125). The HUD
reads it in scripts/ui/flight_hud.gd (`_on_gig_changed` :177, `_update_gig_tracker` :193, the survey
marker :213, input widgets :1045); the tracker is scripts/ui/gig_tracker.gd, the board
scripts/ui/gig_board.gd (`_can_take` :112 duplicates the requirements). Cargo is one float,
`ship.cargo_kg` (scripts/ship.gd:172), `load_cargo(kg)` :1604, `unload_cargo()` :1619 (all of it).
Save VERSION is 2 (scripts/save/save_game.gd:11) with `_upgrade()` stepping versions (:72). There are no
gig tests.

## Decided

- **Up to 3 held gigs** \[Leaning\]: `const MAX_GIGS := 3` in agency.gd. A gig can't be taken with 3
  held; the requirement row replacing ONE GIG AT A TIME reads `GIG SLOT FREE (2 OF 3 HELD)`, met in
  green while fewer than 3 are held.
- **Cargo room is the other limit**, shared by all cargo gigs: the cockpit's 3 t on the lander (1 t on
  the Moon Hopper). `cargo_room()` already counts what's aboard; keep it that way. Mixed cargo and
  survey gigs are fine.
- **Delta-v requirement**: each gig is checked alone, its own `route_delta_v` against the ship's delta-v
  with *all* cargo aboard after taking it (cargo already aboard plus this gig's). No chain planning, no
  sum of routes: that's the pilot's to work out.
- **Storage**: `Agency.active` becomes `var gigs: Array[Gig]` (held gigs, oldest first, only
  state "active") plus `var focus: Gig` (the one the tracker shows in full; null only when none are
  held). Keep `gig_changed(gig)` and emit it whenever the held list or focus changes, with the focus
  (null when none). Add helpers `held_count()`, `is_full()`, `set_focus(gig)`.
- **Focus and target**: taking a gig focuses it and makes its destination the target (as today). Tapping
  another gig in the tracker focuses it and targets it. When the focused gig is paid or fails, focus
  moves to the oldest remaining held gig; the target moves with it only if the target was the ended
  gig's (the HUD's `_targeted_gig` id), otherwise the pilot's own target stays.
- **Per-gig ticking**: `_physics_process` ticks every held gig (cargo step tracking, survey near/scan/
  uplink). Several surveys can uplink at the same moment; each pays on its own.
- **UNLOAD CARGO**: one context-menu row when any held cargo gig at its unload step has its destination
  here. It delivers every such gig at once, each paying and raising its own comms line and chime. Ship
  cargo is lowered by that gig's `cargo_kg`: change `ship.unload_cargo()` to `unload_cargo(kg := -1.0)`,
  where -1 empties it (keep callers that want everything working).
- **SCAN SITE**: offered when landed within reach of any held survey's site at its scan step and not
  scanning. If two sites are within reach (rare), the focused one first, else the oldest. Only one scan
  runs at a time.
- **Survey brackets**: the SURVEY SITE brackets show for every held survey at its find or scan step, not
  only the focused one (one marker per held survey).
- **Losing**: pilot death fails every held gig, unloading all cargo (one comms line:
  `GIG FAILED: PILOT LOST` for one, `3 GIGS FAILED: PILOT LOST` for several). Ship loss fails every held
  gig as `_on_ship_lost` does today per gig (cargo lost, unuplinked data lost), one comms line likewise.
- **Board**: taking a gig no longer closes the board \[Leaning\], so a pilot can take two or three in a
  row. After ACCEPT, the taken row is replaced (as today), stays picked, and the button reads
  `[ GIG TAKEN ]` dark until the pilot picks a row (a tap on any row, or up/down on the Mac), so a
  double tap never takes the replacement. The bottom line shows `GIGS HELD 2/3` beside the balance.
  CLOSE, tap-off, and Escape close as today.
- **Tracker** \[Leaning\]: header `ACTIVE GIG` with one held, `ACTIVE GIGS 2/3` with more. The focused
  gig shows in full, exactly as today. Under it, a thin separator, then each other held gig as one row
  (LINE height): its title cut to fit with `..`, and its distance right-aligned (`12.4 KM`, or the
  survey's `UPLINKING`/`NO RELAY` state when at the uplink step). A tap on a row focuses it. Folded, the
  GIG tab shows the count under the word when more than one is held. The events list under it already
  places itself from `shown_rect()`; it just gets fewer rows. Header taps still fold.
- **Saving**: save VERSION 3. The agency writes `"gigs": [ _gig_state(g) ... ]` and `"focus": id`
  (or -1) in place of `"active"`. `_upgrade()` case 2→3 turns an old non-empty `"active"` dict into a
  one-item `"gigs"` list with focus its id. `restore_state()` unloads the ship, then reloads the sum of
  held cargo gigs' `cargo_kg` (cargo gigs past their unload step carry none).
- No other gig rules change: pay, boards' four slots, refill, hazards, Zen (gigs and pay as normal),
  the med bay bill. No piloting aids, no chain planner, no "best order" hints.

## Tickets

### 1. The agency holds several gigs

- **Does:** the player can take up to 3 gigs; each ticks, delivers, scans, uplinks, pays, and fails on
  its own; UNLOAD CARGO delivers every gig due here; death and ship loss fail them all; saves keep them
  all and old saves load. The HUD and board still work (minimal adaptations: they read `focus` where
  they read `active`), even if they only show one gig until tickets 2 and 3.
- **Touches:** scripts/gig/agency.gd (everything listed under "Today"), scripts/ship.gd
  (`unload_cargo(kg)`), scripts/save/save_game.gd (VERSION 3, `_upgrade`), scripts/ui/gig_board.gd
  `_can_take` (call `agency.requirements` instead of duplicating it), scripts/ui/flight_hud.gd (read
  `focus`), new tests/test_gigs.gd.
- **How:** keep `Gig` as is; the per-gig code in `_track_survey`, `_start_scan`, `_ship_near_survey`
  takes a `gig` parameter. `_pay(gig, what)` removes it from `gigs`, then moves focus as decided.
  Iterate over a copy of `gigs` when paying or failing inside the loop.
- **Check:** new tests/test_gigs.gd, headless, with an Agency and a stub ship or the real lander as the
  other tests build them: take 3 (4th refused with the slot row unmet); cargo room refuses a gig that
  doesn't fit after two loaded; delta-v check uses cargo aboard plus the new; two cargo gigs to one place
  unload in one option and pay both, ship cargo back to the third gig's mass; focus moves to the oldest
  when the focused gig pays; pilot_lost fails all and empties cargo; save → restore round trip keeps
  gigs, focus, and cargo; a VERSION 2 save dict with `"active"` upgrades to a one-gig list. All existing
  suites still pass.

### 2. Tracker and HUD show several

- **Does:** the tracker shows the header count, the focused gig in full, the others as tappable rows;
  tapping a row focuses and targets it; the GIG tab shows the count; survey brackets for every held
  survey; target follows focus as decided.
- **Touches:** scripts/ui/gig_tracker.gd (rows, `_open_height`, `finger_up` hit test per row, tab
  count), scripts/ui/flight_hud.gd (`_on_gig_changed`, `_update_gig_tracker`, survey markers, input
  widgets when `held_count() > 0`), scripts/ui/survey_marker.gd only if one-per-gig needs it.
- **How:** the tracker gets `var others: Array` of `{title, right_text, id}` from the HUD and emits
  `gig_picked(id)`; the HUD calls `agency.set_focus`. Row hit test on the tap's y against the row rects;
  a tap on the header still folds.
- **Check:** all suites; a throwaway windowed screenshot (ticket 3's script) with 3 gigs held: the
  tracker open, one folded tab with the count, and the events list still fitting above the left tab.

### 3. Board for several gigs, and screenshots

- **Does:** taking a gig keeps the board open with `[ GIG TAKEN ]` dark until a row is picked;
  `GIGS HELD n/3` at the bottom; the slot row shows red when full.
- **Touches:** scripts/ui/gig_board.gd (`_accept`, button state, bottom line, row pick resets the
  taken state), scripts/ui/flight_hud.gd only if it closes the board on accept today.
- **How:** a `_just_taken` flag set on accept, cleared by any row pick.
- **Check:** all suites; a throwaway screenshot script (not committed) that starts a normal-play world,
  docks or places the lander at Kapteyn-3, takes 2-3 gigs through `agency.accept` (credits via
  `agency.pay` if needed), and screenshots the board open (with the full slot row red after 3) and the
  flight HUD with the tracker. Export the Android APK; don't install (the Fold is disconnected).

## Art

None. Text and panels only, in the agency palette, as the tracker and board draw today.

## When it's done

- DESIGN.md "Gigs": replace the "One active gig at a time" bullet with the held-gigs rules; update
  "Boards" (requirement row, board stays open, GIGS HELD) and "Tracker" (header count, rows, tab count);
  cargo gigs' UNLOAD CARGO delivering all due here. Change-log row dated 2026-11-14 \[Leaning\].
  (Opus does this, not the builder.)
- Checker: screenshots of the board with 2-3 held and the tracker open and folded.
- Manny tries: at Kapteyn-3 take two cargo gigs to different bases and a survey, fly them in his own
  order, tap tracker rows to switch the target, and check that a 4th is refused and that heavy cargo
  makes the later legs harder.

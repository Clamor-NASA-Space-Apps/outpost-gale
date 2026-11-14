# Mission 1: contracts for the parallel lanes (14 Nov 2026)

The approved script is `design/plans/mission-1.md`. This file pins what five lanes would otherwise guess differently.
All lanes work in this one checkout (`tooling/projects/og-m1`), each in its own files. Lanes do not commit.

## Decided (the plan's open questions)
Mission 1 is Sols 1 to 10 (1 to 5 and 9 played). Sol 2's trade-off is made by hand (no card). No seed decision on
Sol 3. The map lesson moves to Sol 9, the hurry step to Sol 5, the bag lift leaves Sol 1. The handbook key is Tab.
No crewmate. No mission report card: the handbook's Mission log tab shows it.

## Lanes and the files each owns
| Lane | Owns |
|---|---|
| R, the runner | `cine/beats.gd`, `sandbox/sandbox.gd` (`_wire` only), `data/beats.json` keys `_note`, `nag`, `pip`, `outdoors`, `watch`, `tests/quiet_test.gd` (new) |
| H, the handbook | `ui/handbook.gd` (replaces the stub), `ui/handbook/` (new: photos), `data/handbook.json` (new), `ASSETS.md`, `../../../assets-cache/CREDITS.md`, `tests/handbook_test.gd` (new) |
| U, the HUD | `ui/game_hud.gd`, `ui/components/speech_bubble.gd`, `ui/components/event_card.gd`, new files under `ui/components/`, `player/controls.gd` (the `handbook` action only), `tests/ui_test.gd` |
| S1, Sol 1 | `data/beats.json` keys `opening`, `starts`, `ghost`, `offers.sol1_power`; `data/lines.json` keys `sol1.*`, `check.sol1*`, `choice.*` used by Sol 1, `task.*` used by Sol 1; `tests/beats_test.gd` |
| S2, Sols 2 to 10 | `data/sols.json`; `data/beats.json` key `offers.sol5_storm` (new) and `offers.sol12_power`; `data/lines.json` every other key; `tests/sols_test.gd` |

Shared JSON files (`data/beats.json`, `data/lines.json`): change them with exact-string edits of your own keys only,
never a whole-file rewrite, and keep the file valid JSON after every edit (another lane's test reads it).

## Data
**A highlight in a line** (`data/lines.json`): `*words*` marks the key fact. The bubble draws those words in the
`primary` colour token and bold; the asterisks never show. At most two per line. Example:
`"Mars gets *43%* of Earth's sunlight."`

**A teaching line never stops the game.** It is a beat with `"wait": {"time": <seconds>}` (about 4), not `fact: true`.
A line is at most 8 words (kid UX rule).

**A beat unlocks handbook pages** with `"page": "<id>"` or `"page": ["<id>", ...]`, when the beat starts.

**A check** is a beat with
`"check": {"id": "sol1", "q": "check.sol1.q", "options": ["check.sol1.a", "check.sol1.b", "check.sol1.c"], "right": 0, "pages": ["air_tanks", "air_maker", "garden"]}`.
`q` and `options` are line ids, `right` indexes `options` as written (the card shuffles what it shows), `pages` are the
pages that hold the answer. The beat needs no `wait`: it ends on the action `checked:<id>`.

**A decision** stays `"do": ["offer:<id>"]` with `"wait": {"action": "chose:<id>"}`. In `data/beats.json` `offers`:
`"<id>": {"title": "<line id>", "pages": ["<page id>", ...], "options": [{"text": "<line id>", "gain": "<line id>", "lose": "<line id>", "apply": ["<sim choice>", ...]}]}`.
`costs` is no longer used. `gain` and `lose` are short lines ("spare air", "the lettuce waits a day").

**Handbook page ids** (the only ids a beat may name):
- Mars: `light_on_mars`, `thin_air`, `weak_sun`, `cold_nights`, `dust`, `solar_storms`, `gale_lake`
- Our base: `air_tanks`, `air_maker`, `garden`, `seeds`, `water`, `solar_wings`, `reactor`, `oxygen_valve`, `radio`, `storm_shelter`, `rover`
- Explorers: `pip`, `mission_control`, `opportunity`, `insight`, `curiosity`

**`data/handbook.json`:**
`{"tabs": [{"id": "mars", "title": "Mars", "icon": "<ui/icons name>"}, ...], "pages": [{"id", "tab", "title", "lines": [up to 3], "kid": "one line", "source": "NASA ..., factcheck row N", "photo": "res://ui/handbook/photos/<file>" or "", "credit": "NASA/JPL-Caltech"}]}`.
The fourth tab, `log`, has no pages in the file: the handbook draws it from its own state.

## Code
**Runner (`cine/beats.gd`), lane R:**
- `signal page(id: String)`: one emit per id of a starting beat's `page`.
- `signal check_offered(check: Dictionary)`: when a beat with `check` starts. The beat ends on `notify("checked:<id>")`.
- PIP's quiet rules (plan section 2). The knobs stay in `data/beats.json` `nag` and `pip`.

**Root (`sandbox/sandbox.gd` `_wire`), lane R:** `beats.page` to `hud.unlock_page`; `beats.check_offered` to
`hud.offer_check`; `hud.checked` to `beats.notify("checked:" + id)`; on `hud.chosen`, also
`hud.log_decision(<the offer's title line>, <the chosen option's text line>)`; a decision card gets the offer's
`gain`, `lose` and `pages` (pass the option dictionaries through as they are).

**HUD (`ui/game_hud.gd`), lane U.** Stubs with these names are in the file now; replace their bodies:
- `func unlock_page(id: String) -> void`: `handbook.unlock(id)`; when it was new, a "New page: <title>" note for a
  few seconds and the "!" on the book button. Never stops the game.
- `func offer_check(check: Dictionary) -> void`: opens the handbook at `check.pages[0]`; when it closes, the check card
  (question, three shuffled options, a Handbook button). Right: `handbook.learned(check.pages)`, a cue, `checked.emit(check.id)`.
  Wrong: PIP says `check.wrong`, the handbook reopens at the page, then the card comes back. No penalty.
- `signal checked(id: String)`
- `func open_handbook(page := "") -> void`; Tab (input action `handbook`) and a book button open and close it.
  `is_open()` is true while it is open, so the clocks wait and the cursor shows.
- `func log_decision(title: String, choice: String) -> void`: `handbook.log_decision(...)`.
- `offer_choice()` options carry `gain` and `lose` (line ids or plain words) and the card shows them with a plus and
  a minus sign (never colour alone); `pages` non-empty adds a Handbook button to the card.
- The bubble draws `*words*` highlighted (above). Typing still reveals letter by letter.

**Handbook (`ui/handbook.gd`, a `Control`), lane H.** A stub with this API is in the file now; replace it:
- `func unlock(id: String) -> bool`: true when the page was not unlocked before.
- `func learned(ids: Array) -> void`: stamps pages "Learned".
- `func open(page := "") -> void`, `func close() -> void`, `signal closed`.
- `func title(id: String) -> String`
- `func log_decision(title: String, choice: String) -> void`: a row in the Mission log tab.
- `func unread() -> int`: unlocked pages not yet opened.
- `func state() -> Dictionary`: `{"open": bool, "tab": String, "page": String, "unlocked": [ids], "learned": [ids], "total": int}`.
- Its look comes from `ui/theme.tres` and the `Hud` helpers (`ui/hud.gd`): no colour value in code. State lasts for
  the run (no save file).

## Rules for every lane
- Read `AGENTS.md` here and the Code rules in `../../AGENTS.md`: typed GDScript, no em dashes, comments say why, the
  smallest thing that works. No new animation, no new mechanic the plan does not name.
- Every number a kid reads has a `factcheck.md` row (`../../../research/junior-astronaut/factcheck.md`). No row, no number.
- Never say life was found on Mars. No NASA logos. PIP is honest and kind, one short line at a time.
- Engine runs: headless only, `taskset -c 1,2,3,5,6,7 nice -n 10 timeout <s> godot --headless --path . --fixed-fps 60 -s tests/<name>.gd`,
  one at a time per lane. Read the "N failed" line. Never the real screen: someone is playing on this laptop.
- Other lanes land code in this checkout while you work. If a check fails in a file you do not own, wait a few
  minutes and run it again (three times at most), then report it. Do not fix another lane's file.

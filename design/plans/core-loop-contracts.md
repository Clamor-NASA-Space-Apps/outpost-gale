# Core loop contracts (15 Nov, 09:30). Freeze 11:15.

Playtest verdict: the three meters mean nothing, nothing the kid does moves them, the game cannot be lost, the hero
has no needs, hazards do nothing. This wires the rules that exist (sim/sim.gd) to the kid's hands.

## The loop, in the kid's words
| Meter | Goes down when | Goes up when | At zero |
|---|---|---|---|
| Power (battery) | machines are on, wings are dusty, a storm hides the sun | wings wiped, a machine switched off at the power panel | blackout: heat off, the crew gets cold (health falls) |
| Life support (shortest of air, water, food stock) | every sol the crew uses them; an oxygen leak | air maker on (costs water and power), recycler on (costs power), salad picked | mission lost |
| Crew health (you) | suit air out, thirsty, hungry, tired, cold, toxic dust brought inside, a solar storm outside the shelter | a night's sleep; it stops falling once the need is met | mission lost |

Body needs under Crew health: suit air (only outside), water, food, rest. The kid meets a need by HOLDING E at a
spot (a ring fills): drink, eat, fill suit air, brush off dust. PIP says what is wrong once and puts the waypoint on
the fix. Losing shows the three causes and "Try this sol again" (the morning's save).

## Lanes and the files each owns (touch nothing else; do not commit; do not run git stash/checkout/reset)
| Lane | Owns |
|---|---|
| S rules | sim/sim.gd, data/sim.json, tests/sim_test.gd, new tests/body_test.gd |
| H hud | ui/** except ui/handbook.gd, ui/start.gd, ui/boot.gd, ui/settings.gd; tests/ui_test.gd |
| W world | sandbox/interactions.gd, player/player.gd, player/touch.gd, world/dust.gd, data/world.json, data/tuning.json, tests/interact_test.gd, tests/uses_test.gd, new tests/hold_test.gd |
| R root | sandbox/sandbox.gd, sim/sim_node.gd, sandbox/save.gd, new sandbox/advisor.gd, new tests/advisor_test.gd |
| T story | data/beats.json, data/sols.json, data/lines.json, data/handbook.json, cine/beats.gd, tests/sols_test.gd, tests/beats_test.gd, tests/quiet_test.gd, tests/handbook_test.gd |

Another lane's file is wrong or missing something you need: build against this contract, say so in your report, do
not edit it. A check that crashes on another lane's half-written file: rerun once, then report it.

## S: the rules (pure, headless). Game hours as now (1 game hour is about 49 s of play)
New vars, all saved (SAVED), `load()` tolerant of saves without them (`s.get(k, get(k))`):
- `health` 0..100 (starts 100). `body_water`, `body_food`, `body_rest` 0..1 (start 1). `suit_dust` 0..1 (start 0).
- `suit_air_min` as now (full 480, row 135). `outside: bool`, `effort: float` (1.0; the root sets `body.effort_hurry`
  while the hero hurries on foot).
- Knob `body` (false at start): nothing below ticks until the story applies choice `body_on` (Sol 1 teaches it first).

Per tick, only when knob `body` is on and the crew is not asleep:
- outside: `suit_air_min -= dt * 60 * effort`. `eva(false)` no longer refills (the kid fills at a spot).
- `body_water` empties in `body.water_h` awake hours (times `effort`), `body_food` in `body.food_h`, `body_rest` in `body.rest_h`.
- health falls, `body.hurt_per_h.<why>` points a game hour, for each that holds: `air` (outside, suit air 0),
  `thirst` (body_water 0), `hunger`, `tired`, `cold` (battery 0). Suggested: air 150, thirst 8, hunger 4, tired 4, cold 10.
- an active flare while not sheltered: `body.hurt_per_msv` health per mSv of the flare's dose (suggest 4: the X12 day
  unsheltered costs about 32). Sheltered: the halved dose, so half the hurt.
- `suit_dust`: outside with `tau` over clear it rises (`body.dust_per_h_tau`); `dust_hit()` sets it to 1 (a dust
  devil). Not outside with `suit_dust >= body.dusty` for `body.dust_grace_h` (about 12 s of play): health
  `-body.hurt_dust` once, and `suit_dust = 0` (it is in the cabin now). why = `dust`.
- Each kind of harm gets ONE cause-log entry per sol (label from sim.json `body.labels.<why>`, e.g. "Ran out of suit
  air"), its health loss charged to it as `effect.health`; `harm_scale.health` 100. So `top_causes()` names them.
- battery 0 is no longer in `failing()`: it is `cold`. `failing()` = stocks at 0, and `"health"` when health <= 0.

Uses (data/sim.json `uses`): `drink` body_water 1; `eat` body_food 1; `refill_air` suit air full; `brush`
suit_dust 0; `o2_valve` ends any active `leak` event; `sleep_night` also: body_rest 1, health + `body.heal_sleep`
(cap 100), body_water and body_food minus `body.sleep_water` / `body.sleep_food` (so the morning starts with
breakfast). `skip_sols` leaves the body alone.

New event `o2_leak`: kind `leak`, `o2_kg_h` (suggest 5: the tank visibly drops, empty in about 9 game hours),
`chance_per_sol` 0, charged to its log entry, ended by use `o2_valve`. Label "Oxygen leak".

Power made tight (placeholders, say so in their notes): `power.battery_kwh` 140 to 60 so a night shows on the meter;
`events.dust_storm.rise_h` 48 to 10 so Sol 10's morning is dark in the rules too. Rerun the tests that pin them.

`state()` gains: `health`, `body_water`, `body_food`, `body_rest`, `suit_dust`, `suit_air` (0..1), `outside`,
`body` (knob), `cold` (bool), `net_kw` (power in minus out), `hurt` (the why that costs most right now: `air`,
`thirst`, `hunger`, `tired`, `cold`, `flare`, or ""), `leak` (bool). Keeps `suit_air_min` and every old key.
Every new number in sim.json carries a `factcheck` note; a game rule says "game rule, not a fact". Sourced rows to
cite: 135 (suit 8 h), 254 (a forced walk-back used 0.4 lb O2 an hour against Apollo's 0.15), 255 (suited walkers
limited by cooling), 140 (perchlorate, dust likely toxic), 142 (suitports keep dust out), 123 (sweat is water), 188
(8.5 h sleep), 37 and 90 (the flare, the shelter).

## W: hands and body
- Hold to use: a use row with `"hold_s": N` in data/world.json needs E (action `interact`, touch Use button) held N
  seconds on the same target, in reach; letting go or walking off cancels. On completion the row plays as now and
  `used(kind, pos)` fires. `interactions.hold: float` is the progress 0..1, and -1 when no hold is in flight.
  Hold rows: drink 1.5, eat 2.0, refill_air 2.5, brush 2.0, o2_valve 2.0, plant 2.0, harvest 2.0, sample 2.0.
  Instant as now: bed, clean_panel, radio, doors, the rover, the new panel.
- New spots: `refill_air` ("Fill suit air") in the greenhouse and in the shelter (HAB 1 has one); `panel`
  ("Power panel", instant) in HAB 1, on a wall the kid passes. `used("panel", pos)` is all it does.
- `player.stamina: float` 0..1: falls while hurrying on foot and moving (`hero.stamina.drain_s` 20 s from full),
  recovers otherwise (`recover_s` 12); at 0 the hurry lock lets go and cannot be set again under `back` 0.3.
  Numbers in data/tuning.json with a note (game rule; row 255: suited walkers were limited by cooling).
  `player.hurrying_on_foot() -> bool` (hurrying, moving, no vehicle).
- `world.dust.devil_near(at: Vector3) -> bool`: an emitting devil within `devil.touch_m` (tuning, about 6 m).

## H: what the kid sees
- Crew health meter = `state.health`. While `state.hurt` is set, the meter shows why in words beside it (No air,
  Thirsty, Hungry, Tired, Cold, Solar storm). A drop of 3 or more in one state: `bump("-N")`.
- The HUD has at most four progress bars, all full size: Power, Life support, Crew health, Suit air (Ravindu,
  15 Nov 2026). Water, food and rest have no bar: they show as the reason under Crew health, in the Today list and
  in the base report. No hurry bar. A dusty suit (`suit_dust >= 0.5`) shows a dust mark.
- Power shows the flow beside it: charging or draining and `net_kw` ("+2.1 kW" / "-3.4 kW").
- `show_prompt(text: String, hold := -1.0)`: with `hold >= 0` the prompt reads "Hold" and a ring fills round the key.
  A row that needs a hold shows its ring empty before the press: the root passes 0.0 for such a target.
- `set_stamina(v: float)`: a small bar near the bottom centre, hidden at 1.
- `show_causes(list, retry_label := "Try this sol again")`.
- `show_report(d: Dictionary)`: the Mission 1 complete card. `d = {title, lines: Array[String] (line ids or plain
  words), meters: {power, life, health}, causes: Array (as show_causes takes), pages: [found, total]}`. Two buttons:
  "Keep going" and "Play again"; signal `report_closed(again: bool)`.
- SOURCES and the sources card follow the new health meaning (game rule, with rows 135, 140, 37).

## R: the root
- Every physics frame: `sim.sim.eva(player.room == "" and player.vehicle == null)`, `sim.sim.effort`, and on a new
  devil contact `sim.sim.dust_hit()`. Each frame `hud.show_prompt(text, hold)` and `hud.set_stamina(player.stamina)`.
- `beats.rule(id)` (T adds the signal): `apply:<choice>` to `sim.apply`, `event:<event>` to `sim.sim.start`,
  `report:mission1` to `hud.show_report` (Keep going: the next sol runs on; Play again: a fresh game).
- sandbox/advisor.gd, PIP reacting to the state, outside the script: for the first of these that holds and has not
  been said since it last cleared, `beats.aside(line)` and the waypoint on the fix; when the fix is used the step's
  own waypoint comes back. Never while a card, the handbook or a cinematic is up; at most one line every 20 s.
  | When | Line id | Waypoint |
  |---|---|---|
  | outside, suit air 0 | `need.air_out` | `use:refill_air` |
  | outside, suit air under 30% | `need.air_low` | `use:refill_air` |
  | oxygen leak | `need.leak` | `use:o2_valve` |
  | not outside, suit dusty | `need.dusty` | `use:brush` |
  | a devil touched the hero | `need.devil` | none |
  | body_water under 25% | `need.thirst` | `use:drink` |
  | body_food under 25% | `need.hunger` | `use:eat` |
  | body_rest under 20% | `need.tired` | the bed |
  | battery 0 | `need.blackout` | `use:panel` |
  | battery under 25% | `need.power_low` | `use:panel` |
  | health under 40% | `need.health_low` | none |
- The power panel (`used("panel")`): a card through `hud.offer_choice`, one row per switch that can flip now, each
  with its gain and its lose line, plus "Leave it". Line ids: `panel.title`, `panel.close`, and for dev in
  `o2_maker`, `greenhouse`, `recycler`, `heater`: `panel.<dev>.on`, `.on_gain`, `.on_lose`, `.off`, `.off_gain`,
  `.off_lose` (heater on = normal heat, off = heat turned down). They apply the sim's existing choices.
- Losing: `hud.retry` loads this morning's save (as Continue does), not the start of the game.
- `uses` the rules know reach `sim.use` as now (refill_air, brush, drink, eat now do something).

## T: the story
- cine/beats.gd: `signal rule(id: String)` and `do` verbs `apply:<choice id>`, `event:<event id>`, `report:<id>`
  that emit it (look first: reuse what is there).
- Sol 1: PIP teaches the three meters, one line each, when the kid first sees the HUD, and the page "Your three
  meters". Near the end of the day, hands on: fill suit air, drink, eat (each `wait use:<kind>`, waypoint
  `use:<kind>`), with pages "Your suit" and "Eat, drink, sleep"; the step before them applies `body_on`.
- Sol 4: the alarm step starts `event:o2_leak`; the valve stops it. PIP's line says the tank is dropping.
- Sol 5: "It burns air" is true now. The decision's lines name the health cost.
- Sol 10 then sleep: the wake after it runs `report:mission1`.
- Every line the advisor and the panel need (ids above), each at most 8 words, the key words in `*asterisks*`.
  Handbook page "Toxic dust" (row 140) for `need.dusty`.
- Numbers on screen only from the rows named in S. Never say a storm's wind knocks people over: Mars air is too thin.

## Machine rules, every lane
Headless tests only, under `nice -n 19`: `nice -n 19 godot --headless --path . -s tests/<name>.gd` (read the
"N failed" line, not the exit code). No window on the real screen, ever. One engine job at a time per lane. End
every job you start, by PID. Never `pkill -f` or `pgrep -f` loops. No em dashes, no banner comments; typed
GDScript; comments say why; the fewest lines that work. Do not commit.

## Addendum from the audits (09:40)
- S: the garden must cost and pay. Crops grow only while knob `greenhouse` is on. Start knob `greenhouse` false (the
  Sol 1 card's "Light the garden" was a no-op: it set what was already set). `plant` must not wipe the robots'
  lettuce (today it resets `crop_age_days`, so Sol 17's harvest gives nothing): keep the kid's tray as its own age,
  or ignore `plant` while a crop grows, whichever is shorter. A harvest also gives health `body.heal_salad` (10,
  game rule: fresh food is vitamins and morale, rows 29, 121). So: garden = power for health, air maker = power and
  water for air, recycler = power for water. With the 60 kWh battery a night with everything on must visibly drain.
- R: `_lose` wins over everything after it. Today `hud.show_ledger(sim.skip_sols(n))` (sandbox.gd ~703) replaces the
  lost card with the ledger, and the night catch-up (~637) restarts the beats after a loss: return early when `lost`.
  `sim.apply()`'s diff is thrown away (~604): after a choice or a panel flip, tell the kid what moved with a
  `hud.alert` naming the switch and its cost (the line ids `panel.<dev>.on_lose` and so on).
- T: `failing_o2_kg`, `failing_water_kg`, `failing_food_kg`, `failing_health` and `mission_lost` in data/lines.json
  are "TBD": write them. Sol 1's card: both options now change something (air maker on, or garden on); its gain and
  lose words must say what the rules do (air maker: spare air, costs water and power; garden: salad and health
  later, costs power every night).
- H: tests/ui_test.gd pins the old health formula (1 Sv scale) and `ui/fake_state.gd` lacks the new keys: update both.
- Data the game shows is ARCHIVED and on disk (data/nasa.json, written by the data lane): nothing calls a NASA or
  NOAA server at runtime (Ravindu, 15 Nov: the APIs time out).

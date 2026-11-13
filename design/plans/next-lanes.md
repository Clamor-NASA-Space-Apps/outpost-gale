# Next lanes: actions, sleep, audio (plan, 13 Nov 2026)

Written 13 Nov 2026 for the session that merges lanes. Read-only research: nothing here was run in the engine or
Blender, and nothing was downloaded. Every line below is asset or animation prep. **Hard rule 1 holds throughout:**
an action plays a motion, moves a prop and makes a sound. It changes no meter, counts nothing, keeps no sol number
and cannot be won or lost. Where a later rule would hook in, the line says "14 Nov".

Status marks as in `design/research/`: ✅ seen in the source, ⚠️ reported or our maths, ❌ looked for and not found.

What this plan read: workspace `plan.md` (The game), `roadmap.md`, `research/junior-astronaut/challenge.txt`,
`video-subtitles.txt`, `factcheck.md`; this repo's `AGENTS.md`, `design/BRIEF.md`, `CONTRACTS.md`, `ASSETS.md`,
`INVENTORY.md`, `roadmap.md`, `design/research/missing-assets.md`, `alive.md`, `sandbox/interactions.gd`,
`audio/audio.gd`, `audio/make.sh`, `world/sky_clock.gd`, `data/clips.json`, `data/world.json`, `data/tuning.json`,
`forge/hab_interior.py`, `forge/hero_clips.py`, `tooling/skills/day-cycle`, `suited-locomotion`, `living-atmosphere`,
and the caches `assets-cache/music/README.md`, `assets-cache/sounds/README.md`, `assets-cache/quaternius/ual/`.

## 0. Four findings that shape everything below

1. **Indoors the hero is invisible.** In HAB 1, the greenhouse and the shelter the camera goes first person and the
   body is hidden (CONTRACTS.md, First person indoors). An indoor clip nobody sees is wasted. So every indoor action
   plays as a **short third-person cut** (1.5 to 3 s, any move key ends it), then hands back to first person.
   First-person glove hands were considered and skipped: a new rigged asset for one camera mode.
2. **The helmet never comes off** (no faces, workspace rule 8 and "visors, never faces"). Drinking and eating cannot
   be shown at the mouth. Default: a back or three-quarter-back view where the pouch goes up to the helmet's front
   and the helmet hides the rest. Open question 1.
3. **Most interior parts are welded into one mesh** (`interior-col` in `forge/hab_interior.py`): the dispenser,
   the warmer, the berth curtains, the desk screens, the brush, the toilet lid. To use them we need either a box to
   aim at (data only) or a split part that moves (a recipe edit and a re-export). The plan uses data for every spot
   and splits only the few parts that must move.
4. **The animation library is already on disk.** `assets-cache/quaternius/ual/` (UAL1 and UAL2, CC0, licence files
   kept) holds 86 clips, and `forge/hero_clips.py` already retargets UAL's `Walk_Loop` and `Driving_Loop` onto the
   suit. Useful ones not yet used: `Consume`, `Farm_PlantSeed`, `Farm_Harvest`, `Farm_Watering`, `Fixing_Kneeling`,
   `PickUp_Table`, `Chest_Open`, `Sitting_Enter`, `Sitting_Idle_Loop`, `Sitting_Exit`, `Crouch_Idle_Loop`,
   `Idle_TalkingPhone_Loop`, `Push_Loop`, `Yes`, `Idle_FoldArms_Loop` (names read from the GLBs' JSON, 13 Nov).

One mechanism carries most actions, so the code stays small:

- **`data/world.json` `uses`**: per item, a list of use spots in the item's own space:
  `{kind, prompt, box: [x0,y0,z0,x1,y1,z1], stand: [x, z, yaw], clip, prop, verb, sound, shot: [[from], [at]], s}`.
  `sandbox/interactions.gd` makes one Interactable of kind `spot` per row (its `shape` is `box`, its `thing` an empty
  Node3D at the box). `use()` calls `player.perform(clip, stand)`, runs the prop's `verb`, emits `used(sound)` and,
  indoors, asks the cine for `shot`. Picking, reach and the wall test stay exactly as they are.
- **Seven prop verbs**, a fixed set in `interactions.gd`: `swing`, `gather`, `tilt` (the three that exist), plus
  `turn` (a named part rotates about an axis by `deg`), `take` (a prop eases to the hand socket, then hides),
  `appear` (a prop scales up from zero, or one model swaps for another) and `glow` (a lit pane on or off).

## 1. Missing assets

Source route is the factory's order: (1) real NASA data or model, (2) Kenney or other CC0, (3) engine built-in,
(4) code, (5) forge recipe. Size: S under an hour, M 1 to 3 hours, L more.

### 1a. Hero clips (all retargeted or keyed in `forge/hero_clips.py`, written to `data/clips.json`)

| Clip | Why the plan needs it | Route | Size |
|---|---|---|---|
| `kneel_pick` (knee drop, reach the ground, rise) | Samples are the crew's job: "EVA, sample collection, science experiments" (factcheck row 149 ✅); science points (`plan.md` Core loop). A suited reach to the ground is a knee drop and kneel "in one continuous motion", lean about 25 degrees at most (skills/suited-locomotion line 36, Apollo 16 study) | (2) UAL1 `Fixing_Kneeling` for the kneel, hands keyed to the ground; knees and lean capped to the suit | M |
| `plant` (hand to a tray at work height, press) | Greenhouse is an event card: "lettuce needs about 33 days" (`plan.md` Event deck; factcheck row 29 ✅) | (2) UAL2 `Farm_PlantSeed`, reach raised to the rack's tier height (work height 1.10 m, hero_clips.py `WORK`) | S |
| `harvest` (grip, twist, lift to the chest) | Food production is one of the brief's four demands (challenge.txt ✅) | (2) UAL2 `Farm_Harvest` at tray height | S |
| `consume` (pouch to the helmet front) | Water and food are Life support (`plan.md` Core loop; factcheck rows 25, 112 ✅) | (2) UAL2 `Consume`, the hand stopping at the visor, not inside it | S |
| `sit_idle`, `sit_to_stand` | Wake sitting in HAB 1 (section 3); waiting out a storm in the shelter ("stay up to 24 h", factcheck row 35 ✅) | (2) UAL1 `Sitting_Idle_Loop` and `Sitting_Exit`, or the existing suited `drive_sit` with the hands moved to the thighs (cheaper: the suit's sitting angles are already solved) | M |
| `radio` (hand to the helmet's side, head tilt) | "Communication delay" is named in the brief (video-subtitles ✅; factcheck rows 12, 13 ✅) | (2) UAL2 `Idle_TalkingPhone_Loop`, hand stopping at the helmet's side | S |
| `turn_valve` (two hands on a wheel, a quarter turn) | O2 comes from tanks in the first stay (factcheck rows 103, 132, 159 ✅) | (5) keyed from poses in `hero_clips.py`, the way `interact` is | S |
| `fix_kneel` (kneel, hands busy at a low panel) | Repairs to the power yard; "limited power" (challenge.txt ✅) | (2) UAL1 `Fixing_Kneeling` | S |
| `suit_check` (look down at the chest unit, tap, look up) | Suits and dust: why there is an airlock (factcheck rows 135, 142 ✅) | (5) keyed: head tilt and one hand to the chest unit | S |
| `brush` (sweep down a thigh and an arm) | Dust is "likely toxic" (workspace facts ✅); the brush is already on the wall (`hab_interior.py` brush()) | (5) keyed, or (2) UAL1 `Interact` looped twice | S |

### 1b. Props and moving parts

| Asset | Why | Route | Size |
|---|---|---|---|
| Drink pouch with a straw | Drinking water, 2.0 kg a day (factcheck row 123 ✅). A pouch is how the ISS crew drink ⚠️ (photo knowledge, no factcheck row; needed only if a fact card says it) | (5) forge `prop_drink_pouch.py`, 3 parts, `body` and `trim` roles | S |
| Food pouch | ISS food is "thermostabilized, irradiated, rehydratable" packs heated in a "suitcase-like food warmer" (row 115 ✅) | (2) Poly Haven `long_life_food` CC0 (4,712 tris, missing-assets.md §9) decimated, else (5) forge | S |
| Warmer lid as a moving part (`warmer_lid`) | The galley warmer exists but is welded into `interior-col` | (5) edit `hab_interior.py galley()`: keep the lid out of `U`, name it, add to world.json `moving` | S |
| Berth curtains as moving parts (`curtain0`, `curtain1`) | Sleep (section 3); the berths have curtains, welded in | (5) edit `hab_interior.py berths()`; widen the `moving` regex to `curtain[0-9]*` | S |
| Desk screens that light (`screen_glass-1`, `screen_glass1`) | Radio and "Ask Earth" at the desk (BVAD "Mission planning: computer", missing-assets.md §3) | (5) split the two panes; (4) `glow` verb toggles a lit copy of the `glass` role | S |
| Seed packet | Planting | (3) a `BoxMesh` with the `trim` role, 6 x 9 cm, in the hand socket | S |
| Empty tray plug (stage 0) | Planting needs an empty place to plant | (5) a rock-wool cube in `prop_lettuce.py` as `prop_lettuce_0.glb` | S |
| Harvested lettuce stub | "Cut-and-come-again picking" (row 29 ✅) | (2) Quaternius `Lettuce_Harvested.glb`, on disk, CC0, through `forge/prop_lettuce.py` like the other four | S |
| Sample pebbles (3 to 5 marked rocks) | Samples | (2) the Poly Haven scans already in `models/rock_small_*.glb`, placed at 0.25 scale by world.json; a small beacon flag beside each (`prop_beacon.glb` exists) | S |
| Sample bag on the hip | Where the pebble goes | (5) forge, 12 x 18 cm soft bag on the `suit` role, rigid on `thigh_r` in the hero recipe, or (4) attached in code to a BoneAttachment3D | S |
| O2 skid valves as moving parts (`valve_1` to `valve_4`) | Use the O2 tanks | (5) edit `prop_oxygen_maker.py` (valves from Elk3D's model are already there): split and name them | S |
| Suit umbilical hose | Refill the suit's air at the HAB 1 valve panel ("AIR IN", exists) | (4) one cylinder stretched from the panel's port to the chest each frame (look_at plus scale.z) | S |
| Dish turret as a moving part (`turret`) | "Check the dish", aim at Earth; only `dish` (elevation) moves today | (5) edit `building_dish.py`; (4) Earth's direction from DESIGN.night.md `celestial.planets` Earth RA/Dec through `HouseStyle` sky frame | S |
| Battery module doors (`module_door_0..2`) | Repair at the power yard | (5) edit `prop_battery_bank.py`: three doors exist as seams; make them hinged leaves | S |
| Hand tool (driver) | Repair | (5) forge, 2 parts; Poly Haven `metal_toolbox` is 14,228 tris, too heavy | S |
| Suit brush as a carriable (`brush`) | Brush the dust off | (5) split `brush_handle` and `brush_head` from `interior-col` into one node | S |
| Hand sockets (`hand_r`, `hand_l`) | Every `take` verb | (4) `BoneAttachment3D` on the UAL hand bones (`hand_r` is named in hero_clips.py) | S |
| Second crew member | Crew of 2 (factcheck row 132 ✅; decided 12 Nov); the buddy rule, "a minimum of two people" on an EVA (row 143 ✅) | (5) the hero GLB with a second number and stripe tint, as a `prop`. **Not needed for any action below**; listed because the plan has two crew | M |

### 1c. UI pieces (ui/, from `ui/theme.tres`)

| Asset | Why | Route | Size |
|---|---|---|---|
| Sleep picker (section 3) | Ravindu's sleep design | (3) Control nodes, cards built like `event_card.gd`'s buttons; (4) one `_draw()` clock face with a filled wedge for N hours, so no SVG per duration | M |
| Icons `bed.svg`, `sunrise.svg` | Picker cards and the "Sleep" prompt | (5) by hand in the set's stroke style (`ui/icons/`) | S |
| Prompt icons: `drink`, `eat`, `toilet`, `seed`, `pick`, `sample`, `radio`, `valve`, `fix`, `brush` | Kid UX: "icons first" (workspace rule); today the prompt is text only (`interactions.gd` prompt_label) | (5) SVG, same stroke; `use.svg`, `water`, `food`, `oxygen`, `dish`, `science`, `shelter` already exist and cover five of them | M |
| Suit check overlay | EVA suit checks | (3) reuse `ui/components/visor`: three ticks on "Helmet", "Gloves", "Radio". **No values, no O2 number** (a number would be a meter) | S |
| Fade and cut frame | Every cut and the sleep sequence | (3) a ColorRect and a Tween in `cine/` | S |

### 1d. Sound and music
Listed per action in section 4, with routes and sizes.

## 2. Actions to animate

Every row: one physical thing, no game state. **"Changes" is always "no meter, no counter, nothing saved".** A
spot works any number of times. A harvested slot stays a stub until it is planted again; that is the world's shape,
like a bag put down, not a crop that grows (growth is a rule, 14 Nov).

Camera key: **3P** the play camera; **cut** a 1.5 to 3 s shot from `shot`, ended early by any move input, then back.

### Lane A: the hero's clips (`player/`, hero files in `forge/`, `models/character_suited.glb`, `data/clips.json`)
Lane A delivers the clips in 1a and two methods: `player.perform(clip, stand) -> float` (glide at most 0.5 m to the
stand point and turn over 0.3 s, play the clip, return its length) and `player.sit(on: bool)`. During a cut the body
is drawn even in first person (`follow_cam.reveal` held at 1).

### Lane B: props and use spots (the rest of `forge/` and `models/`, `data/world.json`, `sandbox/interactions.gd`)

| Action | Where (model or node) | Hero motion | What the prop does | Sound | Camera | Still missing |
|---|---|---|---|---|---|---|
| Open or close a door | HAB 1, greenhouse, shelter `door` | `interact` (have) | swings (have) | `hiss`, `door_open`, `door_close` (have) | 3P | nothing |
| Draw the toilet curtain | HAB 1 `curtain` | `interact` (have) | gathers (have) | **`curtain` is emitted but no file exists**, so only the chirp plays (`audio.gd used()` has no match for it) | 3P / FP | a cloth swish (section 4) |
| Tilt a panel to shed dust | `panel_N` on the wings (have) | `interact` | tilts, dust sheds (have). Real: "Settled dust is removed via two axis gimbal articulation" (row 183 ✅) | `servo` (have) | 3P | nothing |
| Carry a bag, drive the rover | (have) | (have) | (have) | rover boarding plays only the chirp | 3P | `door_open` plus `hiss` on the hatch |
| **Fill the suit's air** | HAB 1 `valve_panel` ("AIR IN", 58 degrees), a `uses` box on it | `perform("interact")`, then hold | the hose stretches from the panel port to the chest; the panel's status light turns green (`glow`) | connector click, a soft 3 s hiss loop, click off | cut, side view | hose (code), `uses` row. How a real suit is refilled is not in factcheck ❌: keep it off fact cards until sourced |
| **Use the O2 tanks** | gas skid `oxygen` by the airlock, `valve_1..4` | `turn_valve` | a valve wheel turns 90 degrees; the skid's status light changes (`glow`) | metal squeak, `hiss_out` | 3P | split valves, clip |
| **Drink water** | HAB 1 galley `dispenser` (box) | `perform("consume")` | pouch appears under the nozzle, fills (scale on its body 0.3 to 1 over 1 s), eases to the hand socket, up to the helmet front, then hides | pour into a pouch, a short sip | cut, three-quarter back view | pouch, clip, open question 1 |
| **Eat** | HAB 1 galley `warmer` | `PickUp_Table` (from UAL1) then `consume` | warmer lid opens, a food pouch eases to the hand, lid closes | latch click, foil crinkle, the warmer's beep | cut, three-quarter back | lid split, food pouch, clips |
| **Sleep** | HAB 1 lower berth (box over the bedding) | none shown (no lying) | berth curtain closes before the fade | curtain swish | section 3 | section 3 |
| **Use the toilet** | HAB 1 cubicle, a `uses` box in front of the seat | none shown: the hero steps behind the curtain during a fade | curtain closes, 3 s, opens. The urine is stored, not recycled, in the first stay (row 157 ✅) | curtain, a fan whir with suction (the toilet works by air ⚠️ no factcheck row), curtain | cut from outside the cubicle, never inside | fan sound (synth), open question 6 |
| **Plant seeds** | greenhouse racks, an empty `slot_N` (stage 0); also HAB 1's Veggie | `perform("plant")` | seed packet in the hand socket shakes once, then a stage 1 sprout scales up from zero in the slot | packet rattle, a soft pat (the `step_in` sand files at low pitch, on disk) | cut, side view down the aisle | stage 0 plug, packet, clip |
| **Pick lettuce** | greenhouse `slot_N` with a stage 4 head | `perform("harvest")` | the head eases to the hand socket and hides; the slot swaps to the harvested stub | leaf rip | cut, side view | stub model, clip |
| **Take a rock sample** | 3 to 5 marked pebbles near Mont Mercou (landmark `mercou`) and the base, each beside a flag | `kneel_pick` (outdoors, the hero is seen) | the pebble eases to the hand, then to the hip bag, and hides; the flag stays | boot crunch through the suit (have), a rock click (rubberduck `bfh1_rock_hit_01`, on disk), a short zip | 3P; the camera keeps its distance (no new framing) | pebbles, bag, clip. The first sample of a session plays the shipped, unused `discovery` cue (section 4) |
| **Call the base on the radio** | HAB 1 desk (box), also the shelter's `comms_screen` | `perform("radio")` | both desk screens light (`glow`), go dark after the radio sound | `radio_base` (have), Kenney Sci-fi `computerNoise_000` (on disk) as the screens wake | cut, over the shoulder at the screens | screen split, clip. **No delay timer:** "Ask Earth" waits are a rule (14 Nov) |
| **Check the dish** | `dish` drive box (box) | `perform("interact")` | the turret turns and the dish rises to point at Earth's real place in the sky | `servo_out` start and stop, `motor_out` while it moves (have) | 3P | turret split, Earth direction (code) |
| **Shelter from a storm** | storm shelter: door (have), a `uses` box on the lower bunk's edge | walk in, `sit_idle` | none | door (have), the wind outside drops through the shelter's walls (the Outside bus at the shelter's room level, as `player.room` already does) | FP inside; a cut to the hero sitting when he sits | `uses` row. Whether a storm sends you there is a rule (14 Nov) |
| **Repair** | battery bank `module_door_N` | `fix_kneel` | a module door swings open, the driver in the hand socket, the door closes, the status light blinks once | latch, three ratchet clicks, latch | 3P | doors split, tool, clip |
| **EVA suit check** | HAB 1 donning corner (box at the bench) | `suit_check` | the visor overlay shows three ticks, one by one | `suit_fan` spins up (have), Kenney Interface `confirmation_001..003` (on disk) | cut, three-quarter front: visor gold, never a face | clip, overlay |
| **Brush off dust** | HAB 1 by the hatch, `brush` | `brush` | the brush eases to the hand, sweeps, back on its hook; a puff of dust at the legs (`world.puff()`, have) | short bristle scrapes | cut, side view | brush split, clip |

Lane B's split of work: Blender re-exports one at a time (a heavy job each, machine rules). `uses` rows and the four
new verbs need no Blender. `tests/interact_test.gd` grows one standing grid per new spot.

### Lane C: cine and HUD bits (`cine/` new, `ui/components/sleep_picker.*`, new icons in `ui/icons/`, `data/cine.json`)
`cine/cine.gd`: `shot(from, at, seconds)` for the cuts above, `sleep(hours)` for section 3, `busy() -> bool`,
`state() -> {shot, t, picker}`. It owns one Camera3D and the fade. It reads `uses.shot` from Lane B's rows and the
clips' lengths from Lane A through `player.perform()`'s return.

### Lane D: audio (`audio/`, `assets-cache/music/ours/`, `assets-cache/sounds/` new folders, `data/tuning.json`)
Section 4. It replaces `used()`'s `match` with one table `sound name -> files`, so a missing file is a test failure,
not silence (the curtain today).

## 3. Sleep sequence

**Decided 13 Nov 2026 (lead, from the sourced findings below; Ravindu asked for real practice):** two cards, "Night"
and "Nap 20 min", and a night always ends at the fixed 06:30 wake, indoors. Where the text further down says 2, 4,
6 h, "Until sunrise" or carry-on-to-dawn, "What real crews do (sourced)" wins.

### What real crews do (sourced)
Researched 13 Nov 2026; numbers are rows 187 to 208 of `research/junior-astronaut/factcheck.md`, sources saved in
`research/junior-astronaut/pages/sleep/`.

- **Nights are scheduled, not chosen.** NASA protects 8.5 h for sleep each night (row 187). The ISS runs a fixed
  clock: bed 21:30, wake 06:00 GMT (row 188). Crews really sleep about 6 h (rows 187, 188). NASA's 30-sol Mars plan
  for **two crew** keeps the same shape every sol: at least 8.5 h of sleep, 1.5 h "post-sleep" (breakfast), 2 h
  "pre-sleep", 8.5 h of work, at least one non-EVA sol between EVAs (row 205).
- **They live on Mars time.** The plan has the crew on a 24 h 40 min day, shifted weeks before landing, and the
  extra 40 min can be "additional sleep" (row 205). Rover teams on Earth did this too: Phoenix for 78 days, most
  adapted (row 198); MER about half did (row 199); Curiosity's team quit after three months (row 200). In Mars-500
  light fell and one sleeper drifted toward a 25 h day (row 201). HI-SEAS kept Earth time (rows 202, 203).
- **Naps are a real tool,** used more late in ISS missions and around busy nights (rows 193, 197). Short is better:
  10 min leaves almost no grogginess, 30 min can leave you slow for up to an hour (row 194). NASA's pilot nap was a
  40 min chance that gave about 26 min of sleep (row 195). The "34% / 54%" claim is not in NASA's report (row 196).
  HERA banned naps on purpose to study a tired crew (row 204).
- **Where they sleep:** on the ISS, a sleeping bag in a small private cabin, strapped so they do not float, with a
  mask and ear plugs (rows 162, 190, 191). On Mars NASA's standard asks for a **horizontal bed** and windows that
  can block light to 2 lux (row 192).
- **Never in the suit.** Apollo 11 to 14 slept in suits and barely slept; from Apollo 15 they took them off and
  "slept soundly" (row 206). Nobody plans suited sleep on the ISS or Mars (row 207).
- **Waking up:** lights come on, about 1 h of breakfast and news, then the morning planning call with the ground,
  and only then work (row 189); on the Mars plan 1.5 h (row 205). It takes 2 to 4 h to be fully sharp (row 193).

**Recommendations for the game**
1. **Two cards, not four:** **Night** (moon icon, ends at the wake call) and **Nap** (20 min). 20 min sits between the
   10 min with no grogginess and NASA's 26 min (rows 194, 195). Drop 2, 4 and 6 h: no crew picks a number of hours.
   (Tell Ravindu, since the picker below lists four cards.)
2. **A fixed wake time, not sunrise.** A night always ends at **06:30** local solar time, the next one after bedtime:
   22:00 plus the real 8.5 h (row 208), about 25 min after Gale sunrise, so the door still opens on long morning
   shadows. Going to bed late gives a shorter night, as on the ISS. This replaces the "carry on to the dawn key" rule
   below. A nap keeps its hour.
3. **The wake scene shows a crew waking on schedule, indoors:** the berth curtain opens and HAB 1's lights come up
   from night dim (the ISS signal that the crew is awake, row 189). No sunrise through a window. Then cut to the
   hero on the donning bench, already suited: they slept out of the suit and suited up after breakfast (rows 205,
   206). Optional: the clock moves 1.5 h under the black (post-sleep, row 205), so the door opens at about 08:00.
   Any card text ("Breakfast, then plan the day") is story and waits for 14 Nov.
4. **Kid lines, all true:** "On the space station you sleep in a bag on the wall. On Mars there is gravity, so you
   get a bed" (rows 190, 192). "A Mars day is 40 minutes longer. Extra sleep!" (row 205). "The first Moon walkers
   slept in their suits, and hardly slept" (row 206).

### What the hours imply: dawn, not dusk
The clock's sun at Gale from DESIGN.night.md `celestial` (sun Dec about +9 degrees on Mars, latitude -4.59, our
maths ⚠️): sunrise about 06:05, the sunset key (4 degrees) about 06:20 rising and 17:40 setting, full day from about
06:50, the night key (-18 degrees) about 19:10 to 19:30 (DESIGN.night.md says 19:30). Read the real values from
`clock.report()` before tuning anything.

- Bed at 22:00 plus 6 h ends at 04:00, still dark. Bed at 22:00 plus 8 h ends about 06:00, sunrise.
- So a night's sleep wakes at **dawn**. **Dusk** happens only for an afternoon nap: 13:00 plus 4 h is 17:00, just
  before the sunset key. Ravindu's "dusk" reads as a slip for "dawn"; open question 2 confirms.
- **The wake rule (proposed):** wake = start + chosen hours; if the sleep **started in the dark** (sun under 0 degrees)
  and the wake hour is **still dark**, the time-lapse carries on to the dawn key. A daytime nap keeps its hour, even
  if it ends after dark. "Until sunrise" is always one of the cards.

### The picker (kid UI)
- Opened by E on HAB 1's lower berth (a `uses` row, kind `bed`, prompt "Sleep", icon `bed.svg`).
- Title "Sleep how long?" (3 words). Four cards: **2 hours**, **4 hours**, **6 hours**, **Until sunrise**. Each card
  is a clock face with the hours as a filled wedge (drawn in `_draw()`, so colour is never the only signal) or the
  sunrise icon, and at most 2 words. Cards at least 96 x 96 px, every target at least 48 px. A close button (X icon,
  "Not now").
- Keys 1 to 4, arrows and E (focus navigation), touch taps, mouse clicks (the picker stops clicks and shows the
  cursor, CONTRACTS.md cursor rules). The clock waits while it is open: `sandbox._process` sets `clock.paused` from
  `settings.is_open() or cover.visible`; the merge adds `or cine.busy()`.
- The hours are choices, not facts, so they need no factcheck row. They are local solar hours (a sol is 24 h 39 min;
  nobody needs telling).

### The shot, beat by beat (`cine/cine.gd sleep(hours)`, knobs in `data/cine.json`)
| t | Picture | Clock | Sound |
|---|---|---|---|
| 0 | Berth curtain closes (Lane B `gather`), fade to black 0.6 s | paused | curtain swish; effects duck 18 dB (`audio.duck(true)`) |
| black | Hero placed on the wake seat in `sit_idle`; PIP set to `process_mode` disabled where it stands (a time-lapse of a robot creeping at real speed reads wrong, skills/day-cycle section 3) | `clock.driven = true`, `clock.hold_probes = true` | the `sleep` cue starts |
| lapse | **Drone shot**: Camera3D from (-24, 14, -20) to (-14, 9, -27) in world metres (heights over the ground at each point), looking from (3, 1.5, 4) to (4, 2, 6): north-west of the base, looking south-east over HAB 1 toward Mount Sharp, the greenhouse low in the right foreground. Pitch about -20 degrees, so the top third is sky for the stars. A smoothstep dolly, no orbit | `set_hour(from + span * smoothstep(t))` every frame; `lapse_s = clamp(0.9 * span_h, 4, 9)` | music only, wind quiet |
| end | fade to black 0.5 s | `clock.driven = false`; `clock.refresh()`; then `HouseStyle._redraw_probes(root, at)` with the camera inside the outdoor probe (11 frames a probe, `PROBE_FRAMES`) while the screen is black | the cue resolves on a bell |
| wake | cut inside HAB 1: the hero on the wake seat, 2 s, then `sit_to_stand`, then first person facing the hatch | normal | habitat hum back, `audio.duck(false)` |
| door | the player presses E on the door: it swings in and the doorway shows the morning outside | normal | `hiss`, `door_open`, then the `dawn` cue (`audio.music("dawn", true)`) |

Mount Sharp from the door: HAB 1 stands at yaw 180, so its door faces south (`data/world.json` views note, "HAB 1
stands at yaw 180, so its own +Z is north"). Mount Sharp's peak is south-east of Bradbury Landing, a bearing of about
140 degrees from 4.59 S 137.44 E to about 5.08 S 137.85 E (⚠️ our maths from reported coordinates). Through the
doorway it may sit at the left edge. The wake hand-over turns the first-person yaw a few degrees left if the
`wake_door` capture shows the mountain cut off. The dawn sun rises a little north of east, out of the doorway, so the
long shadows run west across the ground in the view.

Wake seat: the bench in the donning corner (`hab_interior.py donning()`, 129 degrees, seat 0.47 m up, 0.4 m deep),
right by the hatch. Risk: the backpack (the hero is 0.70 m deep with it) may cross the curved wall when sitting
square. If the `wake` capture shows that, sit on the bench end turned along the wall. The berth edge was ruled out:
its roof is about 0.8 m over the base, below a seated suited helmet.

### How the clock is driven, and why it stays a look clock
- Only the 14 Nov hook already in CONTRACTS.md: `clock.driven` and `clock.set_hour(h)`. `hours` runs past 24 as it
  does now; nothing reads, shows or stores a sol number, nothing is scored, sleeping restores nothing.
  `tests/run.gd`'s "no game-state keys" check covers the new `cine` key.
- Section 0 adds three small public things to `world/sky_clock.gd` (the merge session does it, so no lane edits
  `world/`): `hold_probes: bool` (skip `_redraw_probes()` while true), `dawn_hour() -> float` (the existing
  `_phase_h.dawn`), and `look_now()` (one `_update_look(false)` on demand).

### Shadows, probes and the light at high speed (skills/day-cycle)
- **Light:** `sun_step_deg` is 0, so the light turns every frame from the same hour as the disc (section 4 of the
  skill). In a time-lapse the sweeping shadows are the point; no stepping.
- **Look updates:** `_update_look` runs at `look_hz` 10, or every frame only when the hour moves over 0.05 h a frame.
  At 8 h in 8 s and 60 fps that is 0.017 h a frame, so the sky colour would step 10 times a second (0.1 h, about 1.5
  degrees of sun, each). If the lapse capture shows banding steps, the cine calls `clock.look_now()` each frame;
  check its cost with `clock.cost_us` (day-cycle check 6) on the phone build.
- **Probes:** a dusk-night-dawn lapse moves the key weights by about 8 in total; at `probe_step` 0.5 that would dirty
  the outdoor probes about 16 times in a few seconds, each one drawn a face a frame. Held for the lapse, redrawn once
  under the black at the end. A stale reflection for 8 s of a wide shot is not visible; a probe pop when the door
  opens would be.
- **Shader variants:** the lapse crosses no threshold the renderer specialises on: the sun's energy and the fog's sun
  scatter floor at 0.002 (`light_floor`, `scatter_floor`), and lamps stay at a glimmer by day, all warmed at load.
- **Shadow range:** the phone preset draws shadows to 25 m (`shadowRange`), and the drone sits about 32 m from
  HAB 1. The cine sets the light's `directional_shadow_max_distance` to about 60 m for the shot and puts it back;
  check the phone capture for blocky edges.
- **Dust:** a lapse during a storm settles coat at `coat_rise_h` (look only); the wake shows dusty panels. Fine.
- **Stars:** `_stars.t` follows `hours`, so the sky wheels during the night part of the lapse (about 15 degrees a game
  hour). That is the shot.

### The music cue
`sleep.ogg`, ours, about 9 s: the A-D-E cell (shared with `first_step` and `quiet`) on a music-box voice, falling and
slowing over a pad that brightens toward the end, resolving on a major chord as the black comes. The lapse length is
a knob; the cue fades out on the cut whatever it is. `audio.music(name, force := false)`: the cine passes `force`,
because `music.gap_s` (60 s) would block the `dawn` cue at the door.

### The test (`tests/sleep_test.gd`, extends the Forge `test.gd`)
1. Hero placed by the berth at 22:00 (`clock.set_hour`, unpinned). `interaction.prompt` says "Sleep".
2. Interact: `cine.picker` true; one second later `sky.hour` has not moved (paused).
3. Choose 6 (a touch on the card, test.gd touches): `cine.shot == "sleep_drone"`, `audio.music == "sleep"`.
4. Advance `lapse_s` plus the fades: `sky.hour` within 0.05 of `clock.dawn_hour()` (not 04:00), `sky.phase == "dawn"`,
   `clock.driven` false, `sky.probe_redraws` up by at most 2, `player.room == "hab1"`, `cam.first` reaches 1.
5. A nap from 13:00 for 4 h ends at 17:00 (not carried on).
6. Open the door: `audio.music == "dawn"`.
7. No game-state key in `render_game_to_text()` at any step (the run.gd list).

Pictures (Lane C registers `sleep_drone`, `sleep_drone_end`, `wake`, `wake_door` with the sandbox's view hook):
`node ../../tools/capture-view.mjs . captures/sleep --views sleep_drone@22,sleep_drone@2,sleep_drone@5,sleep_drone@6.3,wake@6.4,wake_door@6.4 --scale 0.5`
and the same with `--views none` for state. Day-cycle check 4 applies: no midpoint darker or more saturated than both
keys around it. Then Ravindu sleeps once on the A16 web build.

## 4. Audio

### Mood
Sky: Children of the Light is the mood target only: warm, slow, calm, a little emotional, wide reverb, a small motif
that comes back. Never copy its melodies, harmonies or sounds. Our motif is the A-D-E cell already in `first_step`
and `quiet` (assets-cache/music/README.md), so every new cue is a relative of what ships. Rule from
skills/living-atmosphere section 5 and alive.md section 5: music stays rare; the suit and the wind carry the bed.

### 4.1 Wire what is on disk first (no download)
| On disk | State | Wire it to |
|---|---|---|
| `audio/music/discovery.ogg` (ours) | shipped, never called outside tests | the first rock sample of a session (a flag in audio.gd, like `_stepped_out`) |
| `audio/music/mission_lost.ogg` (ours) | shipped, unused | 14 Nov only (losing is a rule) |
| Exploration Theme, Cleyton Kauffman, CC0 (`assets-cache/music/oga-cleytonkauffman-exploration-theme/`) | picked by Ravindu 12 Nov as "title / optional bed", not shipped | the EVA bed (below) |
| Lifewave 2k, The Cynic Project, CC0, credit asked (`oga-cynicmusic-lifewave-2k/`) | picked, not shipped | the habitat bed and the title |
| `freesound-craigsmith-675559` respirator loop, CC0 | downloaded, not shipped | an exertion layer under `breath_*` when hurrying, or nothing (judge by ear) |
| `oga-0new4y-gas-leak` loop, `oga-bart-steam-hisses` (5), CC0 | downloaded, not shipped | the umbilical refill loop; the O2 valve opening |
| `oga-qubodup-snow-footsteps`, `oga-tinyworlds-different-steps`, CC0 | downloaded, not shipped | kneeling on gravel (a crunch under `kneel_pick`) |
| Kenney Sci-fi `computerNoise_000..003`, Interface `confirmation_*`, `scratch_*`, `click_*`, CC0 | on disk | desk screens, suit check ticks, brush strokes, connector clicks |
| rubberduck `bfh1_rock_hit_*`, `bfh1_metal_hit_*` | on disk | rock sample click, repair |
| The other cached music (Gymnopédie No. 1, Heaven Theme, Moon Chime, First Light Particles, ...) | not picked | leave; First Light Particles needs the author asked about AI before shipping (README) |
| NASA Ingenuity audio | on disk | **never**: Ingenuity flew at Jezero, not Gale (repo rule) |
| `audio.used()` "curtain" and "rover" | emitted, no sound | the curtain swish (new) and the hatch's `door_open` + `hiss` |

### 4.2 Music cues
| Cue | When | Source route | Length, size |
|---|---|---|---|
| `dawn` | the door opens after a wake | ours, `make_motifs.py`: pad swell, piano states the full motif (A D E, then F# E D), a bell doubling, long hall | about 20 s, about 190 KB |
| `sleep` | the time-lapse | ours: music-box voice (the `bell()` partials with a fast decay), falling motif, pad brightening | about 9 s, about 90 KB |
| `storm` | `clock.phase_changed("design.storm")`, as `sunset` already does | ours: low D drone, a rubbing second, the motif in D minor (A D F), unresolved, fading into the wind | about 15 s, about 140 KB |
| EVA bed | outside, on foot, after `first_step`; plays one phrase, then rests 2 to 4 minutes (the Breath of the Wild field-music habit, alive.md section 5), ducks 8 dB under any cue | Exploration Theme cut into 3 phrases of 30 to 45 s by `make.sh tune` | about 1.1 MB |
| Habitat bed | inside HAB 1 after the airlock cue, same phrase-and-rest habit, very low | Lifewave 2k, 2 phrases | about 0.7 MB |
| Title | the cover screen | Lifewave 2k opening | about 0.4 MB |

The beds need one new thing in `audio.gd`: `bed(name)` on its own player on the Music bus, separate from `music()`,
so a cue never waits for a bed and a bed never blocks a cue. Levels in `tuning.json audio.bed`.

### 4.3 What can be made on this machine (checked 13 Nov)
- Present: **ffmpeg** (with `aevalsrc`, `anoisesrc`, `sine`, `afir` convolution, `aecho`, `chorus`, `aphaser`,
  `flanger`, low and high pass), **python3 with numpy 2.5.3**, and `assets-cache/music/ours/make_motifs.py`
  (felt piano, bell or celesta, detuned pad, convolution hall, fixed seed).
- Absent: sox, fluidsynth, timidity, any `.sf2`/`.sf3` soundfont, scipy, MuseScore, LilyPond.
- So: every music cue above can be synthesised (add a music-box voice and a Karplus-Strong pluck for a harp-like
  colour, about 10 lines each in numpy; filters through ffmpeg). Sampled orchestral instruments cannot, without a
  soundfont download.
- SFX that synthesise well with ffmpeg alone: the curtain swish (band-passed pink noise, 0.4 s envelope), the toilet
  fan and suction (filtered noise with a rise and fall plus a 180 Hz tone, like `suit_fan`), the umbilical hiss
  (from the cached gas leak), a valve squeak (`aevalsrc` chirp), the time-lapse needs none. Pours, sips, foil and
  leaf rips do not synthesise convincingly: download those.

### 4.4 SFX per action
| Sound | Actions | Route (first that fits) | Size |
|---|---|---|---|
| `curtain` | toilet, berth | synth (ffmpeg), or Kenney RPG Audio cloth (CC0, 50 files, kenney.nl/assets/rpg-audio; file names not read: the page lists none) | S |
| `pour`, `sip` | drink | Freesound CC0 (search with the CC0 filter, 13 Nov; licence to re-read on each page at download): "OpenBottle_Screwtop_pour_drink", Mediaman57, https://freesound.org/people/Mediaman57/sounds/347146/ (4 s); "Swallowing Liquid 4", UnderASpell, https://freesound.org/people/UnderASpell/sounds/693251/ (3 s) | S |
| `latch`, `crinkle`, `beep` | eat | latch: Kenney Sci-fi `impactMetal_00x` (on disk); crinkle: OpenGameArt "202 more sound effects" lists plastic crinkling and velcro, CC0 per the search result, page not readable here (403); beep: Kenney Interface (on disk) | S |
| `toilet` | toilet | synth | S |
| `rattle`, `pat` | plant | rattle synth (short noise grains); pat: `step_in` sand files pitched down (on disk) | S |
| `leaf` | harvest | Freesound CC0 results: "Lettuce Ripping", lunchmoney, https://freesound.org/people/lunchmoney/sounds/382042/ (10 s); "LETTUCE.wav", actionlewis, https://freesound.org/people/actionlewis/sounds/538698/ (3 s) | S |
| `rock`, `zip` | sample | rock: rubberduck (on disk); zip: OpenGameArt "Zipper", AntumDeluge, https://opengameart.org/content/zipper (CC0 per the search result; page 403 here) or Kenney RPG Audio | S |
| `valve` | O2 tanks | synth squeak + `hiss_out` (have) + a bart steam hiss (on disk) | S |
| `connect`, `refill` | suit air | Kenney Interface `click_00x` (on disk); refill loop from the cached gas leak | S |
| `screens` | radio | Kenney Sci-fi `computerNoise_000` (on disk), `radio_base` (have) | S |
| `dish` | dish | `servo_out`, `motor_out` (have) | none |
| `ratchet` | repair | Kenney RPG Audio `metalClick` ⚠️ (name from memory) or Kenney Impact Sounds (CC0, 130 files, https://kenney.nl/assets/impact-sounds) | S |
| `ticks` | suit check | Kenney Interface `confirmation_001..003` (on disk), `suit_fan` (have) | none |
| `brush` | brush | Kenney Interface `scratch_001..005` (on disk), low-passed | S |
| `sit`, `stand` | wake, shelter | suit fabric creak: Kenney RPG cloth, plus a `step_in` thud (on disk) | S |
| `storm_out` loop | the storm | the NASA wind (have) pitched down and layered with filtered noise, gusting harder; a Mars storm pushes softly in thin air, so no roar ⚠️ (alive.md 4.1: "a quieter, more muffled version") | S |
| picker clicks | sleep picker | Kenney Interface `select_00x`, `confirmation_00x` (on disk) | none |

Every outdoor one gets its `_out` copy (900 Hz, baked, `make.sh`). Kenney's site blocks curl (403): Ravindu
downloads the two Kenney packs in a browser. Freesound needs his login. No voices at all, so the minors rule is safe.

### 4.5 Credits and size
- Each new file gets a row in `ASSETS.md` (Sound or Music) and, if downloaded, a credit line in
  `assets-cache/CREDITS.md` with its page saved beside it (`page.html`), as the caches do now. Ours are Apache-2.0
  and AI-written code: the submission's AI-use paragraph already covers `make_motifs.py`.
- **Downloads:** about 6 Freesound files (WAV, 1 to 2 MB each, about 8 MB) plus Kenney RPG Audio and Impact Sounds
  (sizes not on the pages; Kenney's other sound zips here are 0.8 and 5.7 MB, so about 2 to 7 MB). **Total about 10 to
  15 MB** ⚠️ estimate, under the "ask first" line only if Ravindu agrees.
- **Shipped:** about 25 new SFX (clear and `_out`, about 10 KB each, 0.5 MB) and the cues and beds (about 2.6 MB).
  About 3 MB added to the game data; no size cap applies (decided 12 Nov).

## 5. Lanes, in order

**Section 0, the merge session, 45 min, before any lane:** add to CONTRACTS.md the `uses` row shape, the seven verbs,
`player.perform()` and `player.sit()`, `cine.shot()`, `cine.sleep()`, `cine.busy()`, `audio.music(name, force)`,
`audio.duck(on)`, `audio.bed(name)`; the three sky_clock helpers (section 3); stand-ins (a `perform` that plays
`interact`, a `shot` that only waits) so every lane's check runs first. Ravindu's downloads (open question 5) start
in parallel. `ASSETS.md` and `CREDITS.md` rows come back in each lane's report and the merge session writes them:
two lanes writing one file in one checkout clobber each other.

Machine rules in every brief: engines on the hidden display under `nice`, one heavy engine or Blender job per lane at
a time, each lane ends its own background jobs by PID with their X server.

| # | Lane | Folders owned | Skills to load | Check that proves done | Hours |
|---|---|---|---|---|---|
| 1 | D Audio: wire, cues, SFX | `audio/`, `assets-cache/music/ours/`, `assets-cache/sounds/<new>/`, `data/tuning.json` (`audio` key; the only lane that edits this file) | living-atmosphere, godot-audio | `tests/audio_test.gd` grows: every sound name any `used()` emits resolves to a file (fails today on `curtain`); a bed ducks under a cue and never blocks it; `force` passes the gap; first sample plays `discovery` once. `bash audio/make.sh` rebuilds every file the same. Ravindu listens on the A16 speaker | 4 |
| 2 | C Cine and sleep | `cine/` (new), `data/cine.json` (new), `ui/components/sleep_picker.*`, `ui/components/suit_check.*`, new files in `ui/icons/`, `tests/sleep_test.gd` | day-cycle, third-person-camera, camera-systems, frame-budget, godot-3d-essentials, godot-ui-control, godot-animation | `tests/sleep_test.gd` (section 3) 0 failed; the capture set above; `ui/hud_gallery.tscn` shows the picker at phone and laptop sizes; `tests/ui_test.gd` targets at least 48 px | 4 |
| 3 | A Hero clips | `player/`, `forge/hero_*.py`, `data/clips.json`, `models/character_suited.glb` | character-life, suited-locomotion, character-body (Using things), godot-animation, godot-physics | new `tests/clips_test.gd`: each new clip loads with its length; at the clip's work frame the hand bone is within 5 cm of the spot's point; feet slide under 2 cm in place; lean at most 25 degrees and the knee on the ground in `kneel_pick`; `perform()` returns control. One film per new clip (`feel-probe --only`), style-check on the hero GLB | 5 |
| 4 | B Props and use spots | `forge/` except `hero_*`, `models/` except the hero, `data/world.json`, `sandbox/interactions.gd`, `tests/interact_test.gd`, `tests/doors_test.gd` | character-body (Using things), world-collision, godot-physics, godot-nodes-scenes, godot-resources | `style-check DESIGN.md models/*.glb` and `check_godot_project.py .` pass; `interact_test` picks every new spot from its standing grid, from either side where it has two, and none through a wall; every verb returns its part to its start; `world_test` loads every prefab; `run.gd` no game-state keys | 5 |
| gate | merge, sweep, web | all | game-feel-gate, performance-optimization, godot-export | every test, `web-check .`, `/code-review medium`, then **Ravindu plays the web build on the A16 for five minutes**: sleeps once, eats, plants, picks, samples | 1.5 |

Order is priority, not sequence: all four can run at once (they own disjoint folders). If time runs out on 13 Nov,
cut from the bottom of Lane B's table first (brush, repair, dish), then Lane A's keyed clips; the sleep sequence and the
audio wiring are what Ravindu asked for first. Anything unfinished on 14 Nov can continue at the event: assets are
allowed there too.

## 6. Open questions for Ravindu

1. **Eating and drinking with the helmet on.** No faces, so the mouth is never shown. (a) back view, pouch to the
   helmet front (default); (b) a short fade, the pouch empty after; (c) the suit's own drink bag, refilled at the
   dispenser (needs a NASA source first).
2. **Wake time.** A night's sleep wakes at dawn; dusk happens only after an afternoon nap. Confirm "dawn", and the
   wake rule in section 3 (carry on to sunrise only when the sleep started in the dark).
3. **Picker cards.** 2, 4, 6 hours and "Until sunrise", or fewer (only "Nap" and "Until sunrise")?
4. **Music beds.** The research and your picks say music is rare. Do you want the EVA and habitat beds as phrases
   with long rests (default), always on and quiet, or off with only the cues? And Exploration Theme and Lifewave 2k
   for them, or ours?
5. **Downloads, about 10 to 15 MB:** about 6 Freesound files (your login) and Kenney's RPG Audio and Impact Sounds
   (your browser; kenney.nl blocks curl). Approve, or keep to synthesis and what is on disk.
6. **The toilet.** Curtain and sound only, camera outside (default), or leave it out of the sandbox?
7. **Indoor cuts.** Short third-person cuts for indoor actions (default) or stay in first person and show only the
   prop moving?
8. **Organisers' line.** The sleep picker moves only the look clock (like the B key) and counts nothing. Confirm you
   are happy that it sits inside the "assets and sandbox" permission before 14 Nov.

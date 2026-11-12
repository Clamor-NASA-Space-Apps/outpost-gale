# A sol that runs on its own: day cycle, fast time, dust that stays

Written 12 Nov 2026 for Ravindu's ask: "the world runs on its own", a continuous day and night, dust that settles after a storm and stays until cleaned, and "what are the consequences of making time flow fast compared to the player? otherwise the player has to play 30 days non-stop."

Sources are saved in `pages/day-cycle/` (`games/`, `mars/`, `godot/`) and in older folders named per row. Status: ✅ seen in the saved source (kwic or a regex over the text), ⚠️ reported only, secondary, or our own maths, ❌ not found. The generic lessons went into the factory skill `tooling/skills/day-cycle/SKILL.md`.

## TL;DR 🧭
- **A sol takes 20 real minutes by default** (`day_minutes`, from 12 to 24). That is about 74 times faster than Mars. Big games sit in the same band: Minecraft 20 min, Breath of the Wild 24, Subnautica about 20, GTA V 48.
- **The night runs 3 times faster than the day:** about 16 minutes of light, including the long dusk, and 4 minutes of night. This is the same split as Subnautica (4 min 30 s of full night in 20 minutes), and RDR2 also runs its nights faster.
- **The sol starts at 06:30, shortly after sunrise.** The first sunset comes about 13 minutes into the session (our maths).
- **The 30-sol mission cannot be played sol by sol in real time.** At 20 minutes a sol that is 10 hours, and kids aged 8 to 12 game about 1 h 27 min a day. On 14 Nov the rules must skip time: sleeping skips the night as a short time-lapse, and quiet sols are skipped. This is a rule decision for the event, not for now.
- **The look and the rules are kept apart.** From now until the event:
  - One clock (`hour`, 0 to 24) drives the sun, the sky, the fog, the lamps, the sound and the dust devils.
  - It blends the four approved sky designs and counts nothing.
  - The dust coat is its own value, not part of the storm sky.
  - On 14 Nov the sim takes over the clock and adds the sol counter, the skips, and dust lowering power.
- **What kids see:**
  - A butterscotch day.
  - A blue glow around the setting sun.
  - A dusk that lasts (up to 2 h after sunset on Mars).
  - A whirlwind out toward Mount Sharp around midday.
  - Louder wind after dark (Gale's downslope winds are strongest at night).
  - Phobos rising in the west.
  - Dust that dulls the panels, sol after sol, until the wind or the crew clears it.
- **The cheap way to draw it on a phone:**
  - The sun moves in short, smoothed steps every couple of seconds, not every frame.
  - Everything in the sky that changes over time is a global uniform.
  - Reflections and probes are refreshed only a few times a sol.
  - The lamps fade on at dusk, and their shader is warmed when the game loads.

## 1. How games compress time 🎮

| Game | Real minutes per day | Night | Skipping and pausing | Source (`pages/day-cycle/games/`) | Status |
|---|---|---|---|---|---|
| Animal Crossing | real time (1,440) | real | none; the director called clock-changing "a shame" | `nookipedia-time-travel.html` | ✅ |
| Skyrim | 72 (our maths: 1,440 / timescale 20) | real share | wait 1 to 24 h with a time-lapse sky; not near enemies | `skyrim-console-commands.json`, `skyrim-waiting.json` | ✅ (72 derived) |
| The Long Dark | 72 or 120 (the wiki contradicts itself) | 9.5 of 24 h dark | sleep up to 12 h, can't be cut short | `thelongdark-*.json` | ⚠️ |
| GTA V | 48 (2 s per game minute) | not given | a timed mission plays "a brief time-lapse" instead of a wait | `gta-time.json` | ✅ |
| RDR2 | about 48 | time "flows faster during the night" | sleep, wait | `rdr2-conditions.json` | ✅ (wiki footnote) |
| Occupy Mars (a Mars game) | 24 day + 10 night | 10 min | players: "far, far too short"; a mod rescales it | `occupy-mars-steam-night.html` | ✅ (lengths stated by a modder) |
| Breath of the Wild | 24 (1 game hour = 1 real minute) | 21:00 to 05:00 | a campfire or bed jumps to morning, noon or night | `botw-time-zeldawiki.html` | ✅ |
| Minecraft | 20 (72 times faster) | 8 min 20 s, plus 50 s each for dusk and dawn | a bed skips night after 5.05 s; sleeping does not speed up crops or smelting | `minecraft-daylight-cycle.html`, `minecraft-bed.html` | ✅ |
| Subnautica | about 20 | 4 min 30 s of full night | a bed any time, 10 min cooldown | `subnautica-planet-4546b.json`, `subnautica-beds.json` | ✅ |
| Stardew Valley | 14 (6 am to 2 am, 0.7 s per game minute) | from 6 to 8 pm by season | a bed ends the day at any hour; time pauses in menus, dialogue and cutscenes (single player) | `stardew-day-cycle.html` | ✅ |
| Oxygen Not Included | 10 (600 s) | 75 s | none needed | `oni-cycle.html` | ✅ |
| Don't Starve | 8 (16 segments of 30 s) | 2 segments in midsummer, about a third in winter; a light is required | none | `dontstarve-day-night.html` | ✅ |
| Kerbal Space Program | real rotation | real | time warp up to 100,000 times; physics warp 1 to 4 times | `ksp-time-warp.html` | ✅ |
| Frostpunk, Surviving Mars | not found | | Frostpunk Survivor mode: "no active pause", pause only in a menu | `frostpunk-survivor-mode.json`, `surviving-mars-steam-sol.html` | ✅ pause only |

**What players complained about:**
- **Too fast.** Subnautica, 2016: "it makes the game feel like it's in fast forward and I don't actually have the time enjoy a more leisurely pace", including "how fast the clouds, sun, moon and orbiting planet / moon all move in the sky" (`subnautica-forum-day-night-too-quick.html`) ✅.
- **Too short for a routine.** Occupy Mars: "Wake up, eat, drink, harvest, create seeds, make new meals, plant seeds again and you are ready to go to sleep again." ✅
- **Too dark.** Subnautica, 2021, "pitch black at night". The reply: "Night should be dark, but it shouldn't be pitch black." (`subnautica-steam-night-pitch-black.html`) ✅
- **Waiting for a time of day.** GTA V "rectified the issue of having to wait until a certain time to trigger a mission" with a time-lapse ✅.

**How long kids play:**
- Ages 8 to 12 game for **1 h 27 min a day** on average (Common Sense census 2021, `commonsense-census-2021.pdf`) ✅.
- Canada's guidelines for ages 5 to 17 say "No more than 2 hours per day of recreational screen time" (`csep-24h-guidelines-5-17.html`) ✅.
- The AAP gives no fixed hours for school-age children; it recommends a family media plan instead ✅.
- No study found gives a best single session length for ages 7 to 12 ❌. A vendor blog says 5 to 8 minutes per activity for K-2 ⚠️.

## 2. What a fast clock does, system by system ⏩

Our maths (⚠️), from a sol of 88,775 s (24 h 39 min 35 s, Mars24 notes ✅):

| `day_minutes` | Times faster than Mars | Sun's speed | 30 sols with no skips |
|---|---|---|---|
| 12 | 123 | 0.50°/s (1° every 2.0 s) | 6 h |
| 16 | 92 | 0.38°/s | 8 h |
| 20 | 74 | 0.30°/s (1° every 3.3 s) | 10 h |
| 24 | 62 | 0.25°/s | 12 h |

Earth's real sun moves 0.004°/s. The Mars sun disc is about 0.35° wide (secondary ✅). At 20 minutes, the sun crosses its own width in about 1.2 s.

- **Sun and shadows:**
  - The sun moves visibly. Every game in the table accepts this, and Skyrim shows it on purpose in its wait time-lapse.
  - Shadows sweep, most of all at dawn and dusk. With the sun at 10°, a 1.9 m astronaut's shadow grows 1.1 m for each degree the sun drops. At 20 minutes that is about 0.33 m/s, a third of walking speed. At 5° it is 4.4 m per degree (⚠️ our maths).
  - Separate from that sweep, the shadow map's grid turns with the light. Its jagged edges crawl unless the sun moves in steps (section 4).
- **Walking and driving:**
  - These stay at real speed (`reality.json`). The player does not notice the mismatch while the sun stays a backdrop.
  - Players do notice when sky things that should be slow move fast: clouds, moons and the sun together gave Subnautica its "fast forward" feel.
  - So **the wind, dust devils, kicked dust, telltales and clouds keep their real speeds**. Only things that really take hours ride the fast clock: the sun, the sky colour, temperature, frost, the sol's wind pattern, a storm building or clearing, and dust settling.
- **Rare events:**
  - Each keeps its real hour and its real length.
  - A whirlwind at Gale shows up between about 11:00 and 13:00 and lasts real minutes. It does not race across in seconds.
- **Mission time versus play time:**
  - 30 sols at 20 minutes is 10 hours. That is about 7 days of a tween's average gaming (1 h 27 min a day).
  - So the event-day rules need skips:
    - sleep in the habitat to skip the night (as a time-lapse, like Skyrim, GTA V and Minecraft);
    - optionally, skip a quiet sol ("the crew works; next morning");
    - a 30-sol mission played in about 30 to 60 minutes means most sols are skipped.
  - Minecraft's rule is a good one to copy: a skip moves only the clock, and decided processes do not jump with it. **This is a rule decision for 14 Nov.**
- **Menus and reading:**
  - The clock stops while a card, menu or dialogue is open (Stardew does this in single player).
  - Kids read slowly. A clock that runs under a tutorial card punishes them.

## 3. One sol at Gale, for the look ☀️🌙

| # | What | Number | Source | Status |
|---|---|---|---|---|
| 1 | Mean sol | 24 h 39 min 35.244 s; sidereal day 24 h 37 min 22.663 s; rover clocks tick "mean Mars time" (LMST) | Mars24 notes, NASA GISS (`mars/giss-mars24-time-notes.html`) | ✅ |
| 2 | Curiosity landed at 4.6° S, 137.4° E | | MSL fact sheet (`mars/nasa-msl-fact-sheet-2014.txt`) | ✅ |
| 3 | Daylight at 4.6° S stays 11.7 to 12.3 Mars hours all year, so day and night are near equal | | our maths from NSSDC tilt 25.19° | ⚠️ |
| 4 | Day sky: "hazy and reddish or butterscotch colored because of all the dust"; at Gale "more of a butterscotch color to the human eye"; blue-sky versions of rover photos are white-balanced | | NASA 10 things (`mars/nasa-10-things-storms-solar-system.html`); JPL 2013 (`mars/jpl-mount-sharp-panorama-2013.md`) | ✅ |
| 5 | True colour: "brownish gray sky"; "The sky near the sun is a pale blue color" | Pathfinder sol 24, 4 pm | `mars/nasa-pathfinder-true-color-sol24.html` | ✅ |
| 6 | Blue sunset: fine dust lets blue through, so it stays near the sun; "most pronounced near sunset" | Gale, sol 956 | `research/junior-astronaut/pages/nasa-blue-sunset.html` | ✅ |
| 7 | Twilight: "the sky stays bright for up to two hours after sunset", because dust reaches very high | | PIA00783 (`mars/nasa-pia00783-sunset-twin-peaks.html`) | ✅ |
| 8 | Shining ice clouds right after sunset, sometimes iridescent | Curiosity, Mar 2021 | `mars/jpl-curiosity-shining-clouds-2021.md` | ✅ (rare treat) |
| 9 | Frost at Gale: **never seen**. It is only inferred: the ground falls below the frost point "between 4 and 6 am" on 6 sols in late fall and early winter, a layer "of the order of tenths of μm" | | AGU 2014, 2015 (`mars/agu201*-martinez-gale-frost.html`); Martinez 2017 | ✅ |
| 10 | Gale humidity peaks "between 04:00 and 06:00 LMST" | | Martinez 2017 (`mars/martinez2017-ssr-near-surface-climate.txt`) | ✅ |
| 11 | Elsewhere: Phoenix frost "begins to disappear shortly after 6 a.m. as the sun rises"; Viking 2's frost "formed at night and persisted throughout the day" for about 250 sols | | PIA11043; Martinez 2017 | ✅ |
| 12 | Gale day-to-night swing before the 2018 storm: air ~70 K, ground ~90 K; ~30 and ~35 K during the storm | | Guzewich 2019 (`mars/guzewich2019-msl-dust-storm.txt`) | ✅ |
| 13 | Hottest: ground 12:00 to 13:00, air 14:00 to 15:00 local true solar time | | Guzewich 2019 | ✅ |
| 14 | Gale air "daily highs at about ... 0 degrees Celsius and lows at about ... minus 70 Celsius" | | `mars/nasa-steady-temperatures-gale.html` | ✅ |
| 15 | Ground starts warming at 05:00 and peaks near 250 K at about 13:00 (late autumn) | | arXiv 2204.12850 | ✅ |
| 16 | Whirlwinds at Gale peak 11:00 to 13:00 LTST, about one a sol (245 in 707 sols) | | Newman 2019 (`mars/newman2019-jgr-gale-vortices.txt`) | ✅ |
| 17 | They "usually occur at Gale without lifting much dust"; visible dust devils show in the foothills of Mount Sharp (214 in sols 1545 to 1660) | | PIA16914; EPSC 2017-294 | ✅ |
| 18 | Wind turns upslope by day (from the NW/N) and downslope at night (from the SE); night slope winds are strongest, about 21 m/s, from 17:00 to 23:00; the day maximum is about 14 m/s | | Martinez 2017; Ullán 2017 abstract (`mars/cab-ullan2017-gale-wind-pressure.html`) | ✅ (abstract) |
| 19 | Typical mean wind at Gale | | paywalled | ❌ |
| 20 | Phobos rises in the west, crosses in 4 h 15 min or less, about twice a sol; 0.14° wide at the horizon, 0.20° overhead | | Wikipedia (`pages/moons/wikipedia-phobos.html`) | ✅ secondary |
| 21 | Deimos rises in the east and stays up about 2.5 days; almost star-like | | Wikipedia (`pages/moons/wikipedia-deimos.html`) | ✅ secondary |
| 22 | Panels lose "0.2% per Sol" typically (0.05% to 2%); Pathfinder "0.28 percent per day" | | Lorenz 2021; Landis (`pages/dust-coat/`) | ✅ |
| 23 | Wind "cleaning events" make a "sawtooth"; Spirit's power "went up by about 50 percent" after one (sol 420) | | PIA03608; PIA07458 (`mars/nasa-pia07458-dust-devils-seen-by-spirit.html`) | ✅ |
| 24 | InSight had no dust devils at its site, so no cleanings: about 5,000 Wh a sol fell to about 500; last contact 15 Dec 2022 | | Lorenz 2021; PIA25284; NASA | ✅ |
| 25 | 2018 global storm at Gale: peak opacity 8.5; sky cleared with an e-folding time of **43 ± 2 sols**; back to normal by mid-September; dust devils stopped from sol 2082 to 2106 | | Guzewich 2019 | ✅ |
| 26 | Global storms keep dust "aloft for weeks to months" | | NASA storm report (`research/junior-astronaut/pages/storm2018.txt`) | ✅ |
| 27 | Crewed-base studies shed panel dust by tilting: "Settled dust is removed via two axis gimbal articulation", plus "a 5% permanent dust power loss" | | NTRS 20170000235; NTRS 20160011275 | ✅ |
| 28 | An electrodynamic dust shield is "activated only when dust removal is required, perhaps once a sol"; a shield cleared regolith on the Moon (Blue Ghost, 2025) | | NTRS 20120003264; NASA | ✅ |
| 29 | A NASA plan for astronauts brushing panels by hand | | none found | ❌ |

**What this changes in the brief:**
- **Frost at Gale is not a daily sight.** Never show it as fact. If it appears at all, make it a faint dawn sheen on a few winter sols, gone by sunrise, and keep it out of anything a kid is told.
- **The night is the windiest part of the sol at Gale.** Make the wind loud after dark and calm by day, apart from midday gusts.
- **A storm does not clear in a few sols.** The 2018 sky took about 43 sols to fall to a third of its haze. A 30-sol mission that has a storm ends with a dusty sky.
- **"Tilt the panels" has a NASA source; "an astronaut wipes them" does not.** If the game lets a kid brush panels, call it a game action and don't present it as the NASA plan.

## 4. Drawing it in the Compatibility renderer ⚙️

What the engine does (Godot 4.7.2 source in `pages/godot472-gles3-rasterizer_scene.cpp`, `pages/shadows/godot472-servers_rendering_renderer_scene_cull.cpp`; docs in `pages/day-cycle/godot/`):

- **When the sky's reflection cubemap is redrawn** (`_setup_sky`):
  - `reflection_dirty` is set when the sky material's uniforms change (`uniform_set_updated`).
  - It is set every frame for a shader that reads `TIME`.
  - It is set whenever a sky-visible directional light changes direction, energy, colour or size (the `light_data_dirty` check).
  - So **a sun that turns every frame redraws the cubemap all the time**.
  - Our sky shader has custom uniforms, so it runs in `INCREMENTAL` mode: a redraw is spread over 8 frames (`roughness_layers` = 8, docs) and starts again as soon as it ends ✅.
- **Global shader uniforms leave the cubemap alone.** `forge_sky_clock` already turns the night sky this way (`house_style.gd` SkyClock, factory gotcha) ✅.
- **The light can be hidden from the sky shader.** `DirectionalLight3D.sky_mode = SKY_MODE_LIGHT_ONLY` makes the light "not be visible from sky shaders" (docs), and the source skips such lights when building the sky's light buffer ✅.
- **Shadows:**
  - Directional shadows are drawn every frame in Godot whether the light moved or not (the shadow loop in `renderer_scene_cull.cpp`) ✅.
  - Godot keeps edges still against camera movement by snapping to texels in the light's own axes ✅. A turning light carries that grid with it ⚠️ (inferred from the source).
  - On the phone preset, the shadow texel is about 8 cm (`pages/shadows/measured-texel.py.txt`). At 0.3°/s, a texel boundary 25 m out passes every ~20 to 40 frames, so edges flicker one to three times a second ⚠️ (our maths).
  - A Godot maintainer: "many AAA games don't rotate the sunlight continuously, but rotate it by small steps every few seconds instead (with some interpolation occurring between each step)" (`godot/gh-issue-90175-jumping-shadows.md`) ✅.
- **Reflection probes:**
  - `UPDATE_ALWAYS` "has a significant performance cost ... only use one ... at most per scene" (docs) ✅.
  - `UPDATE_ONCE` keeps its old picture until re-dirtied (factory gotcha) ✅.
- **The proven pattern:** Assassin's Creed IV kept "8 key-framed values a day" and blended them at run time (Wronski, GDC 2014, `godot/wronski-ac4-gdc2014.txt`) ✅.

**The plan (look only, before 14 Nov):**
1. **One clock.**
   - A `SkyCycle` node owns `hour` (0 to 24, LMST). It advances by `delta * 24 / (day_minutes * 60)` in the day, and at `night_speed` times that between dusk and dawn.
   - It pauses while a menu is open.
   - Knobs go in `data/tuning.json`, e.g. `"sky": {"day_minutes": 20, "night_speed": 3, "start_hour": 6.5}`. Other lanes are editing that file; add the block when this is built.
   - `render_game_to_text()` reports the hour, the sun's elevation and azimuth, and the blend.
2. **The sun from the clock, moved in bursts.**
   - Elevation and azimuth come from Gale's latitude (-4.59, already in `DESIGN.night.md`) and the season's declination.
   - The light follows in eased bursts of about 1° (1 to 3 s apart at 20 min a sol), and smaller steps below 15° of elevation.
   - Pick the step from a `feel-probe --film` of a shadow edge on the phone preset.
3. **Sky colours blend between the four DESIGN keys by hour**, through global uniforms, never per-frame material parameters:
   - day for 08:00 to 16:00;
   - sunset from about 16:30 to 18:00 at the western horizon;
   - night from about 20:00 (the stars already fade in by the sun's elevation in `_celestial()`);
   - the same keys mirrored for dawn.

   Ambient colour, fog and sun colour and energy are environment and light values: cheap to set each frame.
4. **The sun disc.** Either set the light's `sky_mode` to `LIGHT_ONLY` and draw the disc and halo from a global sun direction, or keep `LIGHT_AND_SKY` and accept one cubemap redraw per burst. Check first that fog sun scatter still shows on the sky with `LIGHT_ONLY`.
5. **Reflections and probes are refreshed in steps:**
   - bump one sky material parameter at each key change, about 6 times a sol;
   - re-dirty the `UPDATE_ONCE` probes at the same moments (`HouseStyle.warm()` knows how);
   - nothing ever uses `UPDATE_ALWAYS`.
6. **Lamps** fade on when the sun drops below about 2° and off above about 6°: hysteresis, with a short stagger. `LampPool` already fades lamps over half a second. Warm the lamps-on shader variant at load in daytime, or the first dusk hitches on the web (`frame-budget` §1).
7. **The night sky shares the clock.** `DESIGN.night.md` `celestial.timeScale: 10` must become 88,775 / (`day_minutes` × 60) (74 at 20 minutes), and `hour` comes from the clock. Otherwise Phobos and the stars drift apart from the sun.
8. **Dust coat as a world value:**
   - It is one global uniform the surface shader reads, raised during a storm and after it, and lowered only by a cleaning event (a gust in the afternoon, or the crew). It is not part of the storm key, because then it vanishes when the storm blends out.
   - Its rate per game hour comes from row 22 above.
   - Panels that the crew cleaned or tilted get a per-object "clean" override. Check that `instance uniform` works in Compatibility on the web before relying on it.
   - On 14 Nov the rules decide whether the coat lowers power.
9. **One problem with the keys as written** ⚠️ (our maths): `DESIGN.md` puts the day sun at elevation 12° and azimuth 345°. If that azimuth is a compass bearing, Gale's sun never stands there: at 12° it is always between 63° and 115° (morning) or 245° and 297° (evening), whatever the season. With a moving sun, the keys hold only colours and the clock places the sun; the fixed angles stay for the still previews.

**Checks** (from the skill):
- State at hours 0, 6, 12, 18 and dusk.
- A counter showing no per-frame sky parameter sets.
- A shadow-edge film on the phone preset.
- Timelapse captures at keys and midpoints, where no midpoint is darker than both its keys.
- The darkest night pixel above black.
- **Ravindu plays one full sol on the Galaxy A16.**

## 5. Recommendation ✅
- **Length:** `day_minutes` 20 by default, from 12 to 24 in Settings or the tuning file.
- **Split:** the night runs 3 times faster, so a sol is about 16 minutes of light (with the long dusk at full length) and 4 minutes of night.
- **Start:** 06:30 LMST, shortly after sunrise. The first sunset comes about 13 minutes in.
- **Night:** short, never pitch black, with base lamps on and the stars, Phobos and Earth up. It is still playable, so a kid can work through it. On 14 Nov, sleeping in the habitat skips it with a time-lapse of a few seconds.
- **Through a sol, a kid sees:**
  - a pale, butterscotch morning that is cold and still;
  - a short, hard-shadowed noon;
  - a whirlwind far off toward Mount Sharp between 11:00 and 13:00;
  - long gold shadows;
  - a blue glow around the setting sun in the west;
  - a dusk that hangs on;
  - lamps fading on, and the wind rising after dark;
  - Phobos climbing out of the west.
- **Dust:**
  - Panels dull a little every sol.
  - After a storm everything is coated, and the sky stays hazy for many sols.
  - An afternoon gust sometimes clears a panel (a sawtooth).
  - Tilting the panels sheds dust, and that has a NASA source.
- **Kept for 14 Nov (rules):** counting sols, the mission clock, sleeping and skipping, storms as events, and dust lowering power.

## 6. Open questions ❓
- Typical mean wind speed at Gale: the papers are paywalled.
- Morning water-ice clouds at Gale: only a search summary so far.
- Opportunity's 2014 cleaning numbers: JPL blocks curl, and only search summaries were found.
- Whether fog sun scatter on the sky survives `SKY_MODE_LIGHT_ONLY`, and whether `instance uniform` works in the Compatibility web build: test both in the sandbox.
- The best single play session for ages 7 to 12: no study found. Decide the 30-sol skip design from a playtest with a kid.

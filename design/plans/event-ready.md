# Event-ready: everything but the story (13 Nov 2026, evening)

Goal: on 14 Nov we only write the storyline (PIP's lines, cards, the order of sols) and wire the flow. Every system,
prop and cinematic below is built and tested tonight with placeholder words. Day design: `design/typical-day.md`.
Research behind it (workspace `research/junior-astronaut/`): `base-gap.md`, `mission-collisions.md`, `judging-2026.md`.

## Decisions taken from the research
- **Where we are:** Gale's landing plain, 197 m west of Bradbury Landing (Curiosity's 2012 landing spot), 2.2 km from
  the site scientists proposed for humans in 2015. The base stays. Say "scientists proposed Gale", never "NASA chose".
- **Curiosity and Mont Mercou are 14.3 km and 8.8 km away, not 124 m and 55 m.** They move to a field site reached by a
  rover trip with a time skip (NASA's 30-sol plan has three rover trips of about 5 sols, up to 20 km). Curiosity is
  "look, photograph, don't touch", dusty, and its position is labelled ARCHIVED 10 Nov 2026 (sol 5070).
- **Samples:** tongs into a sealed tube, tubes into the sample case (100 kg return limit). Dusty suits and trash stay on
  Mars; the crew boards in clean suits.
- **Lettuce takes 33 days, longer than our stay:** the robots that built the outpost started the greenhouse before the
  crew landed. No asset change.
- **The trip home takes about a year** (DRA 5.0 example: 403 days). Never "7 months home".
- **No ice drill** (no near-surface ice at Gale). Mars Sample Return is Perseverance's at Jezero and was dropped in
  January 2026: never link our samples to it.
- **Judging 2026:** AI use acknowledged in text and in metadata; no NASA branding or mission identifiers in generated
  art; every asset, CC0 included, in References with its licence; at least one NASA data source (we have several).

## Lanes tonight (agents, disjoint folders, xvfb + nice, I merge and gate)
| Lane | Owns | Builds | Done when |
|---|---|---|---|
| S, rules | `sim/`, `data/sim.json`, `tests/sim_*` | Meters (oxygen, water, food, power, dose, suit air) from BVAD rates; solar output with dust and time of day; battery, reactor, night heaters; the 24 h 39 min sol clock; events (flare from NOAA data, dust storm) labelled LIVE or ARCHIVED; the sleep ledger for skipped sols; choices with costs; a log of the three choices that mattered most | headless tests prove each rate against its factcheck row |
| P, PIP and beats | `sandbox/pip*`, `cine/beats*`, `data/beats.json` | A beat runner from data (wait for: a place, an action, a time; then PIP goes, points, says line id); "follow me"; the ghost of the same jump on Earth; the Sol 1 opening (start in the airlock, hatch opens on dawn) | the opening plays end to end in a test with placeholder lines |
| U, use spots | `sandbox/interactions*`, props | Eat, O2 valve, plant, pick, samples (tongs, tube, case), radio, brush dust, sit, clean a solar panel (power rises) | each spot plays its motion and sound, and calls a sim hook |
| W, world | `data/world.json`, `models/`, `forge/` | The ascent rocket on its lander at the base edge with a fuel-full light; the sample return box; one trash container by the lander; a weather and radiation mast; a relay antenna; Earth as the brightest star; a dusty Curiosity; the field site with Mont Mercou and Curiosity | style-check, the sweep and captures pass; Ravindu approves the look |
| C, cinematics | `cine/` | Sleep time-lapse from the drone; the rover-trip skip (drive out, fade, "Sol 12", arrive); the launch (outside, then the window, Earth a dot) | each plays in a test and in a capture |
| H, HUD | `ui/` | Meters bound to the sim; visor mail with today's real radio delay; the choice card; the ledger card; the "three choices" replay card; a "where this comes from" source button | the gallery and a play run show live values |

## Order
1. S, P and U first (the event wires these). W and C next. H follows S's state shape.
2. Me: merge the 40 proposed factcheck rows, update the judging notes, gate every merge, push (Actions publishes).
3. Ravindu: the A16 and iPhone check on the Pages link, then approve W's look from captures.

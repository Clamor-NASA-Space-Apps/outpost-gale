# What's left to cook (13 Nov 2026, 08:20)

State: `main` def936b is stable. Every suite, the sweep, style-check and the project check pass. Windows and Linux builds of
def936b are in `~/outpost-gale-builds` (the web zip there is older, from 07:47). Plans and briefs:
`design/plans/next-lanes.md`. Resume notes: `design/handoff/session.md` "RESUME HERE".

## Done tonight (for reference)
- **World:** sky clock, new layout, cables into device ports, rover charger, graded pads and building sites.
- **Rooms:** storm shelter interior, toilet sign, greenhouse rack feet and grow-light wiring.
- **Rover and PIP:** the rover crosses pads and cables, rover lights at night, soft PIP tracks.
- **Hero and sound:** 13 hero action clips, the audio table, the dawn, sleep and storm cues, the music phrases.
- **Screens and builds:** sleep picker card, boot without "not responding", full screen by default.
- **Look:** `paver` pads, low-sun shadow fix (approved).
- **The first use spot:** drink at HAB 1's galley.

## 1. Actions (Ravindu's list, 13 Nov ~04:45): the hero clips exist, the use spots do not
Every action is motion and sound only before 14 Nov, with no meter. Clips are in `data/clips.json`; sounds are in
`audio/audio.gd` SOUNDS. Each needs a `uses` row in `data/world.json`, and often a prop that moves. Full table: next-lanes.md section 2.

| Action | Clip | What's missing |
|---|---|---|
| Drink water | consume (wired) | pouch prop, short third-person shot |
| Eat | pick_up + consume | warmer lid as its own part, food pouch, the row |
| Use the O2 tanks | turn_valve | valve wheels split from the skid, status light, the row |
| Refill suit air | interact | hose from the panel, hiss, the row; needs a NASA source before any fact card |
| Toilet | none (curtain only) | a curtain spot with its sound. Ravindu: nothing else, ever |
| Plant seeds | plant | seed packet, sprout growing in a slot, the row |
| Pick lettuce | harvest | head to hand, harvested stub model, the row |
| Rock samples | kneel_pick | 3 to 5 pebbles with flags near Mont Mercou, hip bag, the row. The glove reaches only 0.44 m, so the pebble eases up to it. The discovery cue plays on the first sample |
| Radio call | radio | desk screens light up, the row |
| Check the dish | interact | dish turret split, turns to Earth's real place in the sky |
| Repair | fix_kneel | battery module doors split, tool in hand, the row |
| Suit check | suit_check | three ticks on the visor overlay, the row |
| Brush off dust | brush | brush on its hook, dust puff, the row |
| Sit and shelter | sit_down / sit_idle | seat spots in the storm shelter and HAB 1 |

Shared work for all of these:
- the four prop verbs `turn`, `take`, `appear` and `glow` in `sandbox/interactions.gd`;
- the short third-person shot for indoor actions;
- moving parts split out of the welded `interior-col` meshes.

## 2. Sleep (Ravindu's design, adjusted to real crew practice, factcheck rows 187 to 208)
- Wire the picker (`ui/components/sleep_picker`, "Night" or "Nap 20 min") to a bed spot in HAB 1.
- The time-lapse: an angled drone shot of the base with the sun and stars moving. It drives only the look clock
  (`set_hour`, `driven`) and counts no sols. Hold the probe redraws, raise the shadow range for the shot, freeze PIP.
- A night ends at a fixed 06:30 wake, indoors: the curtain opens and HAB 1's lights come up, then the hero is on the bench by
  the hatch, suited. The next door opened plays the dawn cue (`audio.wake()`).
- Music: `audio.music("sleep", true)` at the start, `stop_music()` on the cut.
- Test: `tests/sleep_test.gd`, plus pinned-hour captures.
- Card text on waking counts as story, so it waits for 14 Nov.

## 3. To check by playing (Ravindu)
- Listen: curtain, rover hatch, dawn, sleep and storm cues, the music phrases, the synthesised pour, sip, foil and leaf.
- Boot on Windows: splash with a live bar, no "not responding", no wind before the game starts, full screen.
- Graphics switch in Settings: behind the cover, no freeze.
- Phone web: full screen and landscape on the first tap. iOS Safari cannot lock the orientation.

## 4. Look and speed, still open
- Ground speckle at a low sun: specular is ruled out; next, the photo albedo or `shade()` at grazing light.
- Dust devil: a 169 ms shader compile at its first whirl on a cold cache.
- Storm shelter: up to 212 draw calls when looking west through the wall.
- Galaxy A16: profile it, decide the draw-call and fps budget, build an APK.
- Rebuild the web zip with the shadow fix.

## 5. Later, or at the event
- Jumping and climbing (`skills/contextual-traversal`), only if a mission needs high ground. Mont Mercou stays a butte.
- The 2026 judging guide, the Docmost 2-crew page, a 3-lander set, the Gale map pin.
- The Colombo Local Lead's written confirmation that assets may be prepared before the event: ask, and save the reply.
- From 14 Nov: the story, `sim/` rules (O2, power, radiation limit how far you can go, not walls), meters, the sol
  counter, win and lose. The clock hook is ready: `clock.driven`, `set_hour()`, `phase_changed`, `storm_on`, `coat`.

## 6. Housekeeping
- `design/research/pages/interaction/source-sdk-2013-*` stays uncommitted (third-party licence).
- `assets-cache/CREDITS.md` line 43 still says no UAL2 clip ships; 4 do now (Consume, Farm_PlantSeed, Farm_Harvest,
  Idle_TalkingPhone_Loop).
- Two gotchas from the hero-clips lane for AGENTS.md:
  - import a glTF at its own frame rate (24) around `make_all`;
  - retargeted gloves resting on the thighs end up inside the chest unit.
- Tick roadmap.md for tonight's sections.

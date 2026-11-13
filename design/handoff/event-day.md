# Event day handoff (14 Nov 2026, 05:10)

## Where things stand
- **`main` = afc3ae5**, the build on the file server (`~/outpost-gale-builds`, older ones in `old/`). The web build of
  `main` is at https://clamor-nasa-space-apps.github.io/sandbox/. It is pushed to `origin` and `gitea`.
- **Branch `wip/opening-sunrise` (6002d2e, pushed)** holds two things not yet on `main`:
  - Ravindu's new opening staging (lane K): the third-person turn to a sun just peeking over the rim with the hero on
    the left third, a cut to the visor, the "Outpost Gale" title wide, PIP's beep and the look down to him, and a
    slow third-person look-around.
  - Lane T's end of Sol 1: PIP leads to the oxygen maker and the greenhouse lamps, then asks the power question.
  - `cine_test` passes on it. `beats_test` does not (see below).
- **The whole story plays** from Sol 1 to the launch on Sol 31 (`data/sols.json`; `tests/sols_test.gd` plays every sol).
- **Factory** (`tooling`, branch `godot`) and the **workspace** pointer are pushed.

## What is left to finish at the event
1. **`wip/opening-sunrise`, then merge it to `main`:**
   - **PIP's hello spot.** The new dawn shot leaves PIP beside the hero. `pip_hello` then sends him to [2, 12], he
     can't get there and gives up after 30 s. If he stays beside the hero instead, `walk_to_me` ends at once and W is
     never taught. Pick a clear spot a few metres ahead of where `face_dawn` leaves the hero (3.5, 5.5), then make
     `beats_test` pass end to end.
   - **The visor cut** shows the base reflected in the visor, but not the sun. Reframe the cut so the sun light's glint
     sits on the visor.
   - **The title wide:** the parked rover hides the sun. Move the camera behind and to the left of the hero.
2. **The PIP framing:** PIP often hides behind the hero while he leads, because the camera sits right behind the hero.
   This is the worst thing left in Sol 1 (lane P frames under `captures/`; the report is in the session).
3. **The web build size:** game data is 67.5 MB (56 MB gzipped) against a 15 MB budget. It starts and runs, but it is a
   slow download on the venue network.
4. **Story calls for the team:**
   - The 2018 storm never clears before the launch.
   - The sample carry to the rocket is 191 m, about 2.5 minutes of walking.
   - Curiosity is look-only: there's no photo spot.
   - There's no result card yet: PIP's last two lines act as the ending.
5. **Proposed factcheck rows:**
   - Wind both dusts and cleans panels (rows 181 and 16).
   - The Earth date of sol 5070.
   - A sourced length for a regional dust storm.
6. **Smaller items:** `findings.md`, from the review on 14 Nov.

## For Ravindu to check when you play
**Looks (each one is easy to undo):**
- [ ] The new lettuce: red romaine and a green variety (commit d9b2507, captures in `captures/g/`).
- [ ] Your shadow in first person, inside the greenhouse and HAB 1 (commit 604fdfe).
- [ ] The "+0.4 kW" that pops beside the power meter when you brush a wing (Sol 2).
- [ ] The pre-dawn sky at the start (05:48) reads a little mauve.
- [ ] The warmer room-lights proposal, not in the game yet (`captures/i/lights_new/`). It needs a DESIGN.md lamp role.
- [ ] The interiors: sit-up bunks, an ISS-style toilet, the pantry, the herb box and the rover yoke (`captures/i/after/`).

**Play:**
- [ ] Sol 1 from the start: the walk-out, the sunrise, every key PIP teaches, putting the bag down, the choice card
      (it should click through), and the mouse look after the card closes.
- [ ] PIP leading: he never loops at the white boxes, and he stays ahead when you sprint.
- [ ] PIP's bubble and the "PIP 12 m" dot still show when you look away.
- [ ] Doors open only on E, after a hand reach, and never push you.
- [ ] Pick up a box (kneel, grab, carry) and put it down (it drops).
- [ ] Board the rover: the hatch swings open, then a fade.
- [ ] Helmet lights after dusk: on **H** (L turns the camera), with PIP's hint the first time.
- [ ] Look up at the night sky: the camera stays up, up to 60 degrees.
- [ ] Stand on a tilted solar panel's edge: you slide off.
- [ ] Sleep through a night: the next sol's mission starts (Sols 2, 3, 4, 5, then the skip to Sol 9's rover trip).
- [ ] Fast-forward: the sun moves smoothly.

**Settings and decisions:**
- [ ] Should the fps and debug label (bottom left) be off by default for the judges?
- [ ] The story calls in section 4 above.
- [ ] Your friend's four unclear items: turning physics, 3rd person after entering a house, smoke from two places
      with no source, and climbing the ladder.

**Older, from before 13 Nov:**
- [ ] The Pages link on the Galaxy A16 and an iPhone (the weakest devices; about 20 fps on low on 12 Nov).
- [ ] Phone draw calls are about 221 against a 150 target. The look options need your OK: blob shadows on the phone
      preset, the doors as one mesh, the parked rover as one mesh.
- [ ] Onion rings around the sun: send a screenshot.
- [ ] Photos 02 and 05 are missing from `~/Pictures/Outpost Gale/`.

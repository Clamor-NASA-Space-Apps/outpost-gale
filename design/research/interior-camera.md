# The camera inside rooms (14 Nov 2026)

Why: the 14 Nov playtest dropped first person indoors. Ravindu and his friend: "we planned to do third person only
inside the outpost", "avoid camera moving outside and behind the walls in third person inside the hab and
greenhouse", "the character slips/glitches/legs getting reset when entering into the hab", "Starfield already
handles this better". This page is what shipped games and engines do, then our plan. Every source is saved as an
excerpt in `pages/camera/` (file named after each line). Status: ✅ quoted from the fetched page; ⚠️ a search summary
only, the page itself was blocked.

## 1. What games and engines do

### Starfield
- ⚠️ Nothing first-hand on how its third-person camera behaves in ships and outposts. Search summaries: players say
  the default view is close and snaps back; ini keys `fOverShoulderPosX/Z` and `fPitchZoomOutMaxDist` circulate, and
  one poster says they no longer do anything in Starfield. Nothing says it forces first person indoors. We could not
  confirm what "handles this better" is made of, so the plan below rests on the sources that could be read.

### Shipped games (one observer's survey, Game Developer)
- ✅ Doorways are where cameras go wrong: Elder Scrolls Online, "the camera will bounce off the other door, which could
  frighten the player"; Dark Souls 3 "bounces off the walls in tight environments"; Assassin's Creed Syndicate "the
  camera often bounces off objects and walls, which can irritate the player". The Witcher 3 "makes objects close to
  the camera appear transparent"; God of War from inside to outside: "a "hard cut"".
  https://www.gamedeveloper.com/design/third-person-camera-view-in-games-a-record-of-the-most-common-problems-in-modern-games-solutions-taken-from-new-and-retro-games
  (`gamedev-third-person-camera-problems.md`)
- ✅ Super Mario Odyssey dithers Mario when the camera is close and when he is behind a solid: "If the camera is
  close to Mario, we see dots. When Mario is behind a solid, short lines with offset rows." A dither needs TAA to
  blend; our Compatibility renderer has none (skills/third-person-camera rule 9).
  https://threadreaderapp.com/thread/924061000919285761.html (`mario-odyssey-dither-chriswade.md`)
- ✅ Uncharted 3 (GDC 2012): cameras have a "designer/programmer's interface for fading them in/out and priority
  schemes"; no slides found. https://gdcvault.com/play/1015514/The-Cameras-of-Uncharted-3 (`uncharted3-cameras-gdc.md`)
- ⚠️ The Witcher 3 has a closer indoor camera that corrects itself outside (a mod page, blocked). The Sims cutaway
  walls and Baldur's Gate 3's hidden roofs belong to top-down cameras. Nothing found for The Last of Us, God of War's
  interiors, the RE2 remake, GTA V, RDR2, Mass Effect, Fortnite or Gears of War interiors.

### Engines and camera kits
- ✅ Camera volumes: a region switches the camera mode, "you might create a Camera Volume around a narrow corridor to
  trigger a more claustrophobic camera mode", the switch "interpolated (smooth) or instant" (Advanced Third Person
  Camera for UE). https://forrgit.gitbook.io/advanced-third-person-camera/advanced-camera-techniques/camera-volumes
  (`forrgit-camera-volumes-fading.md`)
- ✅ One blend value for the whole tight profile: "The over-the-shoulder switch changes length and Offset from the
  same Alpha" (UE spring arm guide; it also casts "from the arm's base to where the camera wants to be" with a 12 cm
  sphere). https://uhiyama-lab.com/en/notes/ue/camera-spring-arm-guide/ (`ue-springarm-uhiyama.md`)
- ✅ Cinemachine blends between cameras on a curve, "Ease In Out": "S-shaped curve, giving a gentle and smooth
  transition". https://docs.unity3d.com/Packages/com.unity.cinemachine@2.8/manual/CinemachineBlending.html
  (`cinemachine-blending.md`)
- ✅ Cinemachine Deoccluder: "Pull Camera Forward: Move the camera forward along its Z axis until it is in front of
  the obstacle that is nearest to the target"; separate "Damping When Occluded: How quickly to move the camera to
  avoid an obstacle" and "Damping: How quickly to return the camera to its normal position"; "Smoothing Time:
  Minimum number of seconds to hold the camera at the nearest point to the target".
  https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachineDeoccluder.html
  (`cinemachine-deoccluder.md`; Third Person Follow's "Damping Into Collision" and "Damping From Collision" in
  `cinemachine-third-person-follow.md`; the Decollider makes "no attempt ... to preserve the line of sight", in
  `cinemachine-decollider.md`)
- ✅ Lyra-style penetration avoidance (read in OpenTournament's open source, a UE game whose camera mode follows
  Lyra's): the main ray snaps in ("don't interpolate toward this one, snap to it"); side feelers at 16 and 32 degrees
  either side (weights 0.75 and 0.5) "detect nearby walls and move the camera in anticipation. Helps prevent
  popping", blended in over `PenetrationBlendInTime = 0.1f` and out over `PenetrationBlendOutTime = 0.15f`.
  https://github.com/OpenTournament/OpenTournament/blob/master/Source/OpenTournament/Camera/UR_CameraMode_ThirdPerson.cpp
  (`lyra-penetration-opentournament.md`; the same idea, "Lyra-inspired", in `ugc-collision-modifier.md`)
- ✅ StraySpark's Godot camera: in at once, out over 0.5 s, "keep it near 0 so the camera never sees inside a wall";
  "the rig never yaws on its own to dodge walls" (after Nesky).
  https://www.strayspark.studio/docs/godot-camera-system/third-person-and-deocclusion (`strayspark-godot-deocclusion.md`)
- ✅ Size the camera to the space: "Set a max distance that fit your levels so it does not have to break los or push
  in to often." https://sites.google.com/site/doreturnend/design/design_perspective/design_perspective_third-person
  (`gamedev-pensieve-third-person.md`). And "In a confined space like an interior hallway or stairwell, even a few
  inches ... can make a difference" (cast the near plane, not a ray:
  https://www.gamedeveloper.com/programming/accurate-collision-zoom-for-cameras, `gamedev-accurate-collision-zoom.md`)
- ✅ Godot's SpringArm3D: "useful for 3rd person cameras that move closer to the player when inside a tight space";
  it snaps, so easing out is ours (`godot-springarm3d.md`).
- ✅ Steps: Source smooths the eye over a step instead of letting it jump: the view follows at 150 units/s and never
  more than one 18-unit step behind (`CBasePlayer::SmoothViewOnStairs`).
  https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/shared/baseplayer_shared.cpp
  (`source-sdk-2013-smooth-stairs.md`)

### What holds across them
1. Third person stays; a room gets its own tighter profile (shorter arm, shoulder offset), blended on one value with an
   ease-in-out curve. Nobody we could read forces first person.
2. Pull in at once on the main cast, ease out slowly; feelers either side pull in early so a door frame does not pop it.
3. Keep the camera out of walls rather than fading walls (fading needs sorted transparency or TAA); fade the hero
   only when the lens is very close.
4. The camera never turns itself to dodge a wall.
5. Ceilings: nothing direct; Lyra keys the camera offset to pitch, and a narrower pitch range keeps the lens under a ceiling.

## 2. The plan for Outpost Gale (done 14 Nov)
- **Third person everywhere.** First person indoors is gone (`player/follow_cam.gd`: no eye, no reveal; the interaction
  target is picked by the heading, inside as outside).
- **A room profile on one blend value** (`follow_cam.indoor`, tuning.json `camera.in_*`): arm 1.9 m (HAB 1 is 4.8 m
  across), the arm's root 0.35 m right of the hero, the pivot at 1.45 m, pitch -35 to +35 degrees, no wall lift
  (it lifts into the ceiling), no glance. It blends in from `in_approach` (3 m) before the door, by the hero's
  distance to it, so the arm is already short when it meets the frame, and stays 1 inside; `in_ease_s` caps a teleport.
- **The lens stays in the room**: the sphere cast against the walls as before, plus the room's plan from
  `data/world.json rooms` shrunk by the sphere: the arm is cut where its line leaves the plan. That clamp blends in
  over the first metre past the plan's edge (`in_keep`), so walking in the lens comes through the door behind the hero
  in one eased move, never pulled to the hero's back.
  The sweep test found two holes in the cast: the greenhouse dome is a one-sided shell, so the arm's cast from inside
  passed out through the glass (now `world.gd _layer()` turns on back-face collision for every concave collider); and
  HAB 1's toilet curtain sits on the thin layer, which the arm ignores, so the lens sank into it (in a room's profile
  the arm now collides with the thin layer too). The arm is also capped at the plan's depth from its middle, so the
  2.6 m storm shelter gets a 1.25 m arm.
- **Feelers** at 16 and 32 degrees either side (Lyra's weights), in the room profile only: the lens moves in toward
  what they allow over 0.1 s before the arm itself is hit.
- **Walls are kept out, not faded**: cheap in the Compatibility renderer (no sorted see-through walls), and what most
  games do. The hero fades only as outdoors, by the lens's gap to its body.
- **Steps**: the drawn body follows a step at one step per 0.12 s (Source's rate) and is never more than a step behind
  (`player.gd`, tuning.json `hero.step_catch_s`).

## 3. The legs glitch on entering HAB 1 (found 14 Nov)
Filmed frame by frame (a headless walk in, logging the body and the clip state):
- HAB 1's hatch collar has a bevelled inner edge; the deck slab behind it sits 1.5 cm lower (0.385 m against the
  collar's 0.40 m). At 2.23 m from the centre the body's floor ray met that bevel: steep and below the body, so
  `_settle()` called it an edge and the body left the floor for one frame.
- One frame off the floor sent the model to `hop_air`, then `hop_land`, then back to `move`, which restarts the
  walk cycle: the legs snapped to the fall pose and back, "legs getting reset".
- In the same second the old first person hid the body (shown 1 to 0 at the door), which read as part of the glitch.
- The greenhouse's vestibule sill rose 0.18 m in one frame (drawn feet popped up), and walking out of it the body fell
  off the sill for 15 frames.

Fixes: the floor ray looks just past a bevel and steps down onto the floor there, within a step (`player.gd _settle`);
the model plays its fall only after 0.1 s off the floor (`hero_model.gd`, tuning.json `hop.fall_after`); the drawn
body catches up a step smoothly. `tests/indoor_test.gd` checks the feet never pop and the fall clip never plays on a walk in or out.

# Third-person camera feel (excerpts)
Fetched 2026-11-12. Quotes verbatim unless marked "summary".

## John Nesky, "50 Camera Mistakes", GDC 2014 (Habr translation, Part 2, inborn_killer, 10 Dec 2015)
URL: https://habr.com/en/articles/272825 (WebFetch). GDC Vault: https://gdcvault.com/play/1020460/50-Camera
- #26 slopes: "Поэтому лучше сделать рейкаст на некотором расстоянии впереди персонажа." (cast a ray some way ahead of the character, average the height change, use the normal to tell a wall from a hill)
- #27 rule of thirds: rotating the camera about its own axis to frame off-centre is wrong; slide it sideways.
- #28 flight: "всё, что полетело вверх, рано или поздно упадёт вниз." (show where the player will land)
- #31 near targets: shift the camera sideways or back rather than rotate; #32 far targets: rotate.
- #33: tilt down onto the character so the player sees past it.
- #40: smoothing needs a limit on how far the character drifts from the centre; the camera can also lead in the direction of travel after a while (Yoshi's Island).
- #41/#42: zoom (narrow FOV) amplifies motion; quick FOV changes cause nausea.
- #43/#44: shake and walking bob: offer settings, bob must be possible to turn off (nausea).
- #45: on jumps, "мы можем просто оставить камеру в покое." (leave the camera alone)
- #46: fast camera moves read like a cut; cut instead.
- Game Developer write-up: "Cameras are most noticeable when they fail." https://gamedeveloper.com/design/video-50-common-game-camera-mistakes----and-how-to-fix-them

## Max Kaufmann (Giant Squid), "Camera Control in ABZU" (no date shown)
URL: https://giantsquidstudios.com/Camera-Control-in-ABZU (WebFetch)
- "We expanded on the basic ideas that John Nesky developed for Journey"
- "Tracking Position - the world-space location we're looking at, usually the diver's collar-bone."
- "Framing - where the tracking position is placed on-screen, typically positioning the diver according to the rule of thirds."
- "smoothing (using critically-damped springs, to avoid acute speed-hitches)"
- "Mirror the fluidity of the diver's movement while still following predicatively rather than lagging behind."
- "Apply easing to the interpolation so it's not an unnatural linear movement"
- "when the Diver flips, we don't want to swing the camera around with her."

## Max Kaufmann, "Tech Breakdown: Third Person Cameras in Games", Little Polygon blog, 14 Jan 2023
URL: https://blog.littlepolygon.com/posts/cameras/ (WebFetch; quotes capped by the tool)
- "People naturally, but naively, think about the camera as a second actor in the world" (Lakitu in Super Mario 64)
- summary: instead "consider instead the player on the 2D picture plane": place the player on screen, control how much of the screen the player covers, let the player steer the view direction. Framing is a 2D viewport value.
- "you probably want to be bottom-third when looking horizontally"; looking down: centred; looking up: bottom-centre, maybe shifted sideways.
- Solar Ash: "no horizontal smoothing which would cause the camera to lag as Rei zipped around at 45MPH." and "only applied vertical smoothing to clean up uneven terrain" (summary: the player position was projected onto the ground so jumps were not tracked).
- "you can also do that with field-of-view, but it'll make people sick"

## Handheld noise (industry practice, for reference only)
- Activision patent US 12,485,347 (abstract only): "applying a coherent noise function to each of the six axes of the first-person virtual camera" "such that it simulates the movement of a camera handheld by the player/virtual character". https://www.patentarcade.com/video-game-patent/US12485347/
- Unite talk on Homeworld: Shipbreakers procedural cameras (search summary, 80.lv): a procedural camera "feels very robotic, there's brittle motion which is not compelling"; fix with "tuneable tracking and dampening for each axis". https://80.lv/articles/procedural-camera-systems-in-homeworld-shipbreakers

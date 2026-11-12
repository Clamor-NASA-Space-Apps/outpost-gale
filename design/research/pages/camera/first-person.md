# First person indoors: notes (12 Nov 2026)

Why: in the 12 Nov playtest the third-person camera had no room inside HAB 1 (5 m drum) and the greenhouse:
ceiling hits, straight-down views, swings through walls, the hero filling the screen. Ravindu's decision: first
person inside, third person outside. Status: ✅ seen in the saved source, ⚠️ from a search summary only.

## Switching view at a doorway
- ⚠️ No commercial game found that switches to first person indoors by default. The closest is a Skyrim SE mod
  (https://www.nexusmods.com/skyrimspecialedition/mods/69500, page behind a bot check, read through a search
  summary): first person inside, third person outside, and it "won't change again until you go through the entrance
  again": the switch happens once per crossing, which is the hysteresis we need.
- ⚠️ Fortnite (UEFN) docs suggest lining the camera up with the player's first-person viewpoint when entering a
  zone rather than cutting (https://dev.epicgames.com/documentation/fortnite/change-a-players-point-of-view-with-cameras-in-unreal-editor-for-fortnite).
- ✅ Meta, locomotion comfort: discontinuities in camera position or orientation (teleports, snap turns) are a
  comfort tool, and acceleration should be minimised (meta-locomotion-comfort.html,
  https://developers.meta.com/horizon/design/locomotion-comfort-usability/). For us: a short ease, not a long
  glide, and the yaw carried over so the world does not turn under the player.

## Motion sickness (first person, phones, kids)
- ✅ Xbox Accessibility Guideline 117 (xbox-agl-117.html,
  https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/117): "intentional decisions
  around settings related to camera field of view, camera bobbing, motion blur, weapon sway, automatic changes in
  camera angle, and more are critical"; asks whether anything moves the field of view or camera angle "without being
  initiated by the player". For us: no head bob, no auto-turn indoors, no roll.
- ✅ Game Accessibility Guidelines (gag-camera-movement.html,
  https://gameaccessibilityguidelines.com/avoid-or-provide-option-to-disable-any-difference-between-controller-movement-and-camera-movement/):
  "Games that have two types of movement going on at once, such as head bob ... make me sick every single time."
  Avoid any difference between controller movement and camera movement (bob, smoothing, tilt).
- ✅ Field of view. de Vries et al. 2007, VIMS (vries-2007-fov-cybersickness.pdf,
  https://www.ieda.ust.hk/dfaculty/so/pdf/Pages89-95-VIMS2007.pdf): "Games usually have a vertical IFOV in the order of
  75-90º"; mismatch between the rendered and the seen field of view did not raise sickness (the opposite was found).
  Minecraft, a kids' game (fov-minecraft-options.html, https://minecraft.wiki/w/Options): FOV is vertical,
  default "Normal" 70 degrees (102.4 degrees across at 16:9). For us: keep the lens's 75 degrees vertical in both
  views, so the switch has no zoom.
- ⚠️ Children: motion sickness susceptibility was "highest in the range between the age of 4 and 13", severe
  episodes most between 6 and 9 (Henriques et al., J Neurol 2019, https://pubmed.ncbi.nlm.nih.gov/31087161/, page
  blocked to curl, read through a search summary). Our players are 7 to 12: the comfort rules are not optional.

## Showing the body in first person
- ⚠️ Firewatch: "our animator really wanted the full body experience all the time": looking down shows Henry's whole
  body walking, climbing, picking things up (Jake Rodkin, Unity Made With page, search summary; the page 404s now).
- ✅ VRChat head chop (https://creators.vrchat.com/avatars/avatar-components/vrc-headchop/, read with WebFetch): "VRChat
  automatically 'chops off' the avatar's head bone by setting its transform scale to almost 0. This stops the head
  from clipping into view from the user's first-person perspective." It does not change mirrors or other players'
  view. Unreal's HideBoneByName does the same (forum answers, ⚠️).
- ⚠️ Forum practice: put the camera at the head bone plus an offset in front, not on the animated bone, to keep the
  clip's head motion out of the view (Unreal forums, search summary).

## What we built from it
- A room volume per building; the switch happens once per crossing, with a doorway band as wide as the body.
- A 0.4 s ease between the follow position and the eye along the arm's free line, the yaw carried over.
- Eye fixed in the body (from the visor in the rest pose), no bob, no roll, same 75 degree vertical FOV.
- First try (12 Nov): head bone scaled to almost 0 (VRChat's way), arms and legs drawn, the eye leaning out past the
  chest to look down. Ravindu's play (12 Nov 21:12): "much better than last time", but the shoulders and upper arms
  crossed the lens as big pale triangles whenever the body moved, and on the way out the hero showed cut by the near
  plane, then popped whole. Decision: hide the whole hero in first person, the usual way (Half-Life, Halo, Portal
  show no body or only a viewmodel; the coordinator's examples, not checked against a source), and fade it back in
  over 0.2 s only once the lens is clear of its drawn box.

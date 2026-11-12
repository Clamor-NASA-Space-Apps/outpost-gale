# Making Outpost Gale feel alive

Written 12 Nov 2026 after Ravindu's playtest: "it looks good but feels static, like a model walking inside a rendered world", and "the follow camera feels like a drone". Sources are saved as excerpts in `pages/alive/` (one file per topic, URL and fetch date on each). Sounds are in `assets-cache/sounds/` (see its `README.md`).

**TL;DR.** The sandbox has no sound at all, a hero with no motion of its own on top of the clips, a camera that tows itself behind the hero, and objects that move on tweens. Every game the user named fixes those four things with small, cheap layers, and the cheapest by far is sound. Mars gives us a gift here: outside is nearly silent (NASA's mic team "thought the microphone was broken, it was so quiet"), so the loud thing is the suit you are inside. Put the suit's fan and breath in the player's ears, footsteps on the real contact frames, a thin muffled wind outside, and a clear humming habitat inside, and the world stops being a picture. Then give the hero a breath, a head that looks at things and a body that leans; frame the hero like a camera operator would instead of dragging a drone behind them.

Kid version: Mars is quiet, but your spacesuit is noisy. Hearing your own breathing and your boots crunch is what makes you feel you are really there.

## 1. Why it feels static 🔍

A friend's honest read of what the build has and lacks today (12 Nov, commit 7f6a82d):

- **Silence.** No `audio/` folder, no player. Marty O'Donnell (Halo's audio director): "Ambient sound is one of the main ways to immerse people psychologically" and "Games that have sounds that skip, drop out, or have periods of silence tend to lose my attention" (2002 Q&A). A silent game reads as a render, whatever it looks like.
- **A hero with only clips.** The suited hero (agent H) has good clips, but nothing on top: no breath, no head turning toward things, no lean into a turn, no settle when it stops. Naughty Dog found that animating only parts of the neck and spine "made the character look stiff", and fixed it with additive layers that give "natural 'swaying' on arms and head" and a combined look-at (Gyrling, GDC 2008).
- **A camera that is an actor, not an operator.** The rig keeps the hero dead centre and follows through a spring with a limit, plus a slow lead. Max Kaufmann (ABZU's camera): "People naturally, but naively, think about the camera as a second actor in the world". A second actor following you around at a fixed height and distance is, literally, a drone. His alternative is to decide where the hero sits on the screen (framing) and solve the camera from that.
- **Objects without weight.** Panels tilt and bags move on tweens. Nothing thuds, sinks, puffs or settles, so nothing seems to have mass.
- **The world's motion is all particles.** Dust streaks, a far dust devil and footprints are in (good, and sourced). But no machine moves on its own, nothing reacts to the wind, and no light blinks, so the base itself feels switched off.

Steve Swink's definition of game feel names the missing part: "real-time control of virtual objects in a simulated space, with interactions emphasised by polish". We have the first two. This document is about the polish.

## 2. What the games you named actually do 🎮

- **Journey.** Its sound designer: "The robe and scarf loops are always reading a few variables from code ... player velocity, wind speed, and for the scarf, scarf length", and "Left steps were distinguished from right steps for a back-and-forth sound". The first version "played all of their sounds at random and seemed pretty dumb and robotic" (Steve Johnson, 2012). The lesson is not "more sounds": it is that every loop listens to the game. The camera came from John Nesky, whose rules we already follow (pages/alive/camera.md). Austin Wintory wrote the score as "a big cello concerto where you are the soloist" with the other instruments as "the world around you", and kept sound effects "pretty subtle" but there to "make the world feel tactile and real".
- **Halo.** Griesemer's "30 seconds of fun" was really "a 3-second loop inside of a 30-second loop inside of a 3-minute loop that is always different" (2011). For a sandbox before 14 Nov that means: walking, hopping, opening a door, carrying a bag must each feel good on their own, at the 3-second scale. O'Donnell's point on ambience is above.
- **Death Stranding.** The walk is the game. The level designer wanted Sam to "lean or sway, and then readjust his balance, based on changes in cargo weight", and the sound team added "the sound of wind hitting against Sam's body" (505 Games Q&A, 2020). Weight is shown by the body reacting, not by a number.
- **No Man's Sky.** Paul Weir kept ambiences "as natural as possible, using lots of original recordings", and passed the audio "as much information as practical": weather, indoors or out, in a vehicle. With one "storminess" value and an indoors flag he added "shakes and creaks, when indoors and a storm is raging". He is against synthesising wind: natural wind "can be cold, gentle, spooky, reassuring".
- **Hellion** (a space survival game whose sound team wrote its method up in detail). In vacuum "the only way to hear anything is either through direct impact or via vibrations when in contact with a solid object", "simply low passing ... would not sound good enough", and lower air pressure means "the smaller the max distance". Character movement is three sound layers: "Footsteps Type, Suit Type, and Weapon Type". The habitat's ambience is its life support: "air generators, nodes, and air filters". Dead Space's remake drives "Isaac's heart rate, breathing, and dialogue delivery" from one system (A.L.I.V.E.).
- **Real spacewalkers.** Garrett Reisman: "Mostly what you hear is the sound of the pumps and fans that circulate air and water through your suit", plus Mission Control "fairly regularly". It is not "the silent lonely environment with no sound other than your own breathing". NASA on a GoPro spacewalk: "a persistent humming and clanking", "the spacesuit's fan, which circulates air and also drives the water pump and water separator".

## 3. The hero's own motion (character feel) 🧑‍🚀

Clips give the gait; layers on top give the life. Each one is small, and each one is a classic animation principle with a real reason behind it.

1. **Breathing.** A slow rise and fall of the chest and pack, on the spine bone above the hips, timed to the breath you hear. A resting adult breathes 12 to 18 times a minute (MedlinePlus); after a lope it gets faster, then slows back down. This is Naughty Dog's separate "Breathing" layer. The sound and the motion must share one clock, or the player hears a breath the body did not take.
2. **A head that looks.** `LookAtModifier3D` (Godot 4.7: "helpful for moving a character's head to look at the player") on the head bone, aimed at the nearest thing you can use, at a dust devil when one is out, or where the camera looks when nothing else wants attention. A suit limits it: the helmet turns with the torso, so give the spine a share of the turn and keep the angles small. Anticipation in the animation sense is exactly this: "attention focusing on an object that a character is about to pick up" (twelve principles).
3. **Lean and settle.** Lean into acceleration and into turns, lean back when braking, and let the body overshoot a little and come back when it stops: "loosely tied parts of a body should continue moving after the character has stopped ... then 'pulled back' towards the center of mass" (follow through). A heavy pack is the loosely tied part. Epic's Paragon smoothed the hips "via springs"; one damped spring on the upper spine does the same here. The suit's lean limits come from the `suited-locomotion` skill (a pick-up leaned about 25 degrees, Apollo 16).
4. **Carrying shows.** With a bag, the hero leans to balance it and walks a little stiffer (Death Stranding's sway, scaled down to a sandbox).
5. **What not to do.** No bouncy squash on a person ("in realistic animation ... an object's volume does not change"), no wobble that pulls attention: secondary action must "emphasize, rather than take attention away from the main action".

Godot also ships `SpringBoneSimulator3D` for chains that wiggle (hoses, a tether, a scarf): it "attempts to return the original pose after modification". The suit has no loose cloth, so it is optional; a hose from pack to helmet would be the one place.

## 4. Sound, the biggest win 🔊

### 4.1 What Mars really sounds like
All from NASA's own pages (pages/alive/sound-mars.md):
- "a quieter, more muffled version of what you'd hear on Earth"; the air is "about 100 times less dense"; "only lower-pitched sounds would travel long distances".
- Sound speed about 240 m/s against about 340 m/s on Earth (low pitch 240, high pitch 250).
- "On Earth, sound might drop off after about 213 feet (65 meters); on Mars, it falters at just 26 feet (8 meters), with high-pitched sounds being lost completely at that distance."
- "mostly, a deep silence prevails". Mars gets a little louder in its high-pressure season.
- Rover wheels: "clanky, squeaky" metal on rock. Ingenuity: "a distinctive, low-pitched sound at 84 hertz", barely heard from 80 m.

So outside, the world is faint, low and short-range. Everything loud is on you: the suit.

### 4.2 Four layers, four buses
| Bus | What plays | How it sounds | Source |
|---|---|---|---|
| **Suit** (non-positional, always on outside) | fan and pump hum, breathing, a soft radio squelch now and then, the bag rubbing the suit | close, dry, loud enough to be the floor of the mix | Reisman, NatGeo, Hellion |
| **Body** (non-positional) | footsteps, a landing, gloves on a handle | felt through the boots more than heard through the air: low, thuddy | Hellion ("contact with a solid object"), Journey L/R steps |
| **Outside** (3D, short range) | wind, the rover, a door motor, a hiss | pre-muffled, quiet, gone within a few metres | NASA (8 m, high pitch lost) |
| **Habitat** (inside only) | air handling and oxygen machine hum, clear door and footstep sounds | clear, full, Earth-like air | Hellion's "air generators, nodes, and air filters" |

The airlock is where the player feels Mars: outside, the Body and Suit layers dominate and the world is muffled; the door closes, a hiss pressurises the lock, and the Habitat layer fades up while Outside fades out. Weir's "indoors flag" idea is the whole switch.

### 4.3 The catch: a Godot web build cannot filter sound
The brief assumed an `AudioEffectLowPassFilter` on a bus. **That does not run in our web export.** Since Godot 4.3 a web build plays audio in **Sample** mode, and the 4.7 docs say plainly: "AudioEffects are not supported", "Reverberation and doppler effects are not supported", "Positional audio may not always work correctly". The engine's web code (`library_godot_audio.js`, 4.7.2) gives a bus volume, mute, solo and a send, and a player pitch, and nothing else. Forcing **Stream** mode brings back effects but "may cause high audio latency and crackling" (pages/alive/godot-web-audio.md).

What works instead:
- **Bake the muffle into the file.** Make an "outside" copy of each outdoor sound with the low-pass already applied (`ffmpeg -i in.wav -af "lowpass=f=<cutoff>,lowpass=f=<cutoff>" -ac 1 -c:a libvorbis -q:a 3 out.ogg`). Pick the cutoff by ear against NASA's recordings; Ravindu's notes suggest 800 to 1500 Hz, which is a starting guess, not a sourced number.
- **Crossfade by volume, not by filter.** Inside and outside are two buses (or two copies of a sound); the airlock fades one bus down and the other up. Bus volume works in Sample mode.
- **Short range by distance settings, not by filters.** Outside `AudioStreamPlayer3D`s get a small `max_distance` so they really fall away within metres, as NASA measured.
- **Variety by pitch and choice.** Random pick from a set plus a small random `pitch_scale` (supported on the web) stops the "dumb and robotic" repetition Journey's designer heard.
- **Unlock audio on the first tap.** Browsers block autoplay: the docs suggest asking for a click, tap or key first. The sandbox's first touch can be that.

### 4.4 What to download and what is on disk
- On disk now: NASA's Perseverance wind (filtered), rover self-noise, rover driving, laser and Ingenuity recordings; CC0 footsteps on sand, stone, gravel, snow over gravel; CC0 hiss, steam bursts, a motor hum loop, 75 hits and falls; Kenney sci-fi doors, engines, computer noise, and 100 UI blips.
- Needs a Freesound login (all checked CC0): mask breathing, a respirator loop, an oxygen concentrator hum, fan loops, airlock doors, servos, a radio beep (exact URLs in `assets-cache/sounds/README.md`).
- The most honest suit breath: an adult on the team breathing into a bike helmet or a bucket, recorded on a phone. That is what a helmet does to a breath.

## 5. Music and silence 🎵

- Jenova Chen built Journey's emotion around music first ("Prototyping for the emotional Journey actually began around its music"). Wintory treated the player as the soloist.
- O'Donnell warns against both extremes: silence loses attention, and (as summarised by the Codex Gamicus wiki, not his own words) non-stop music "detract[s] from the overall impact". Breath of the Wild used sparse piano "to accentuate ambient sounds", and its field music sometimes faded away entirely, leaving nature sounds.
- For Mars this lands neatly: the suit bed is never silent, so music can be rare. A short motif (a few notes, one instrument) at a few moments: the first step outside, the sun touching the rim at sunset, the airlock closing behind you. Everything else is wind, suit and boots.
- Licensing: music is an asset, so it can be made or chosen before 14 Nov; it must be CC0 or our own, credited like the rest.

## 6. A camera operator, not a drone 🎥

What the camera people say (pages/alive/camera.md):
- **Frame, don't follow.** ABZU places the diver "according to the rule of thirds" and follows "predicatively rather than lagging behind". Kaufmann: put the hero in the "bottom-third when looking horizontally". Nesky #27: get the off-centre frame by sliding the camera sideways, never by rotating it off the hero.
- **No horizontal lag at speed.** Solar Ash used "no horizontal smoothing which would cause the camera to lag" and "only applied vertical smoothing to clean up uneven terrain". Our spring trails a steady walk by `2 v / follow_rate` (tuning.json): at a lope that is the hero visibly towing the camera. Keep the spring for starts and stops, but let a steady walk sit at the framing point.
- **Read the ground ahead.** Nesky #26: cast a ray some way ahead of the hero and pitch for the slope, so walking up a dune shows the crest and walking down shows the floor. A camera that ignores the ground is what makes the world feel like a backdrop.
- **Point at what matters, gently.** Nesky #31 and #32: for something near, shift the camera sideways or back; for something far (a dust devil, the habitat at dusk), rotate a little. Never while the player is looking (#35), and never take control away (#34).
- **Keep the frame calm.** No walking bob, no shake by default (Nesky #43, #44: nausea, give a switch). Field of view changes slowly or not at all (#41, #42). If the idle frame needs life, a very slow, very small drift that fades in after a few seconds of standing still is the most it should get, behind the same switch. That is the "handheld" idea (Activision patents noise on all six axes) at a size a 7-year-old on a phone will not feel. Treat it as the last thing to try.

## 7. The world moves on its own 🌬️

Everything here is real at Gale, which is why it is worth adding:
- **One wind, many listeners.** A single gusting wind value (direction from `world.json`, strength from slow noise) drives the dust streaks' amount, the wind sound's volume, a telltale's angle and the rover's dust. Journey's loops read "player velocity, wind speed"; Weir's ambience reads "what the weather is doing". When everything breathes with the same gust, the eye and ear believe one wind is blowing.
- **A telltale you can watch.** NASA's Phoenix lander measured Mars wind with a telltale on a mast, photographed swinging. A small one on the habitat mast is real, cheap and tells kids the wind's direction. Thin air moves it little (Ravindu's notes: a 100 mph Mars wind pushes like an 11 mph Earth breeze), so small swings, not a flapping flag.
- **Dust devils, in their season.** NASA saw them at Gale "scooting across the ground" on "summer afternoon[s]", and "dust blowing across the ground appears as pale horizontal streak". The build already has a far devil and streaks. Time the devil to the afternoon and let the camera hint at it once.
- **Ripples move, but slowly.** Curiosity saw ripples "moving from sol to sol". A ripple texture scrolling while you watch would be wrong. Leave ripples still; let gusts lift a thin sand streak off crests instead.
- **Machines alive.** Solar panels turning slowly to follow the sun (with a faint servo whine when you are close), a dish nodding, the rover's status light blinking, habitat windows lit at dusk. Reisman's "ghosts in the attic dragging chains" is the flavour: small mechanical life you notice.
- **The sky.** The blue halo at sunset and the long twilight already live in `DESIGN.sunset.md`. Curiosity photographed sun rays through clouds at sunset in Feb 2023, the first clear ones on Mars: a rare treat for the sunset sky, not a default.

## 8. Objects with weight 🎒

Things feel heavy when the world answers them:
- **Set-down.** A bag lands with a low thud (through the Body bus if the hero holds it, through Outside if it drops away), a small grit puff at the contact from `ground-contact-fx`, a few millimetres of sinking into dust, and a tiny settle (a lean that comes back). The sink depth and puff speed are reality-sheet rows.
- **Slow in, slow out.** Panels and doors ease in and out ("needs time to accelerate and slow down"), with a motor sound whose pitch follows the speed, and a clunk at the end stop. A tween with a linear curve reads as weightless.
- **The carrier reacts.** The hero's lean (section 3) is half of a heavy bag's weight. The other half is sound: the bag's straps creak against the suit on each step.
- **Rover.** Its body rolls a little in turns and settles after a stop; wheels throw grit at the tread (already in `ground-contact-fx`); its motor whine rises with speed and its metal wheels "clanky, squeaky" on rock, like Perseverance.

## 9. Limits we work inside (Godot 4.7 Compatibility, web) ⚙️

- Audio: Sample mode on the web, so no bus effects, no reverb, no doppler; bus volume, mute, send and player pitch do work. Bake filters into files. Ask for a tap before the first sound.
- Rendering: no decals, no SDFGI, no volumetric fog, no `emit_particle()`, no particle trails (see `ground-contact-fx`). `GPUParticles3D` one-shots and shaders are fine.
- Size: OGG mono loops of a few seconds are small; long NASA clips should be trimmed to the useful seconds before they go into the game's 15 MB.
- Rule 1: none of this changes game state. Sounds, motion and light only.

## 10. Prioritised touch-ups (soul gained per hour) 🏁

Costs are rough, for one agent who knows the code. Each item names the folder it touches; `audio/` is new (one small `audio.gd` autoload plus the bus layout, owned by whoever merges it).

| # | What | Why (source) | Cost | Folder |
|---|---|---|---|---|
| 1 | **Suit bed + audio unlock.** Four buses (Suit, Body, Outside, Habitat); a looping suit fan/pump hum and a breathing loop on Suit, always on outside; first tap unlocks audio | The loudest real sound on a spacewalk is the suit (Reisman, NatGeo); silence loses attention (O'Donnell); web blocks autoplay (Godot docs) | 1.5 h | audio/, player/ |
| 2 | **Footsteps on the contact frames.** Left and right sets, random pick and slight pitch, louder at a lope, softer at a walk, sand vs stone by surface tag; landings thump both feet | Journey split L/R steps; Hellion's footstep layer; contact times exist in `data/clips.json` (suited-locomotion) | 1.5 h | player/, audio/ |
| 3 | **Muffled outside bed.** NASA's filtered wind, baked low-pass, quiet, gain driven by the gust value; outside 3D sounds get short `max_distance` | Mars "deep silence", high pitch lost by 8 m (NASA/JPL) | 1 h | audio/, world/ |
| 4 | **Airlock in and out.** Door motor, a pressurise hiss, then crossfade Outside down and Habitat up (air handler hum, clear steps); reverse going out | The contrast is how a player feels thin air (Ravindu's notes, Hellion's pressure parameter, Weir's indoors flag) | 1.5 h | sandbox/, audio/ |
| 5 | **Breathing body + head look-at.** Spine rise and fall on the same clock as the breath sound (12 to 18 per minute at rest, faster after a lope); `LookAtModifier3D` to the nearest usable thing or the camera's aim, small angles, torso shares the turn | Naughty Dog's breathing and look-at layers fixed "stiff" (Gyrling); MedlinePlus rate | 2 h | player/ |
| 6 | **Camera framing.** Hero on the lower third, no horizontal lag in a steady walk (spring only for starts and stops), vertical smoothing only, ray ahead for slope pitch | ABZU and Solar Ash (Kaufmann), Nesky #26, #27, #40 | 2.5 h | player/ (follow_cam.gd, tuning.json) |
| 7 | **Lean and settle.** Lean into acceleration and turns, back on braking, a damped overshoot of the upper spine on stopping; extra lean with a bag | Follow through (twelve principles), Paragon hip springs (Delayen), Death Stranding sway | 1.5 h | player/ |
| 8 | **Set-downs with weight.** Thud, contact puff, a few mm sink, a small settle for bags and crates; eased panel and door motion with a motor whose pitch follows speed, a clunk at the stop | Slow in and out; ground-contact-fx; rubberduck CC0 hits on disk | 1.5 h | sandbox/, world/ |
| 9 | **One gust, many listeners.** A noise-driven gust feeding dust streaks, wind volume, a mast telltale and rover dust | Journey's loops read wind speed (Johnson); Weir's "what the weather is doing"; Phoenix telltale (NASA) | 1.5 h | world/, audio/ |
| 10 | **Machines alive.** Panels track the sun slowly with a near-only servo whine, a dish nods, the rover's status light blinks, habitat windows lit at dusk | Hellion's life-support ambience; Reisman's clanking; makes the base feel switched on | 2 h | world/, sandbox/ |
| 11 | **Rover sound and roll.** Motor whine with pitch from speed, NASA's "clanky, squeaky" metal wheels on rock (baked muffle outside, clearer when the hero is inside the cab), body roll in turns and a settle | NASA rover driving audio (Maki) | 1.5 h | sandbox/, audio/ |
| 12 | **Radio and suit blips.** A wordless squelch and a status chirp every minute or two, from Kenney Interface sounds | Mission Control talks "fairly regularly" (Reisman); no words, so no story before 14 Nov | 0.5 h | audio/ |
| 13 | **A rare music motif.** A few notes, one instrument, at the first step outside, at sunset and when the airlock closes; never wall to wall | Chen, Wintory (player as soloist), O'Donnell against non-stop music, BotW's sparse piano | 3 h (finding or writing CC0 music) | audio/ |
| 14 | **Camera hints toward a dust devil or the base at dusk**, once, gently, after the player stops looking | Nesky #30 to #36 | 1 h | player/, world/ |
| 15 | **Idle camera drift (optional, behind a switch).** A very slow, tiny drift only after standing still for a few seconds, fading in and out | Handheld noise (Activision patent) vs Nesky #44 nausea; try last, judge on a phone | 1 h | player/ |

The first four are about six hours together and change the game more than everything after them. Each one ends with Ravindu playing the web build on his phone, with sound on.

## 11. Open questions ❓

- Which breathing recording: Freesound CC0 mask breathing (needs a login) or our own helmet recording?
- Music: does the team want a motif at all, and who makes or picks it?
- The low-pass cutoff for the outside layer: set by ear against NASA's clips on the target phone's speaker (small speakers lose the low end; Journey's bass tone "was blowing out small TV speakers").
- Does a heartbeat layer (Dead Space, Hellion) belong in a kids' game? Probably only after a long lope, very quiet, or not at all.

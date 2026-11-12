# Character feel and secondary motion (excerpts)
Fetched 2026-11-12. Quotes verbatim unless marked "summary".

## Christian Gyrling (Naughty Dog), "Creating a character in Uncharted: Drake's Fortune" (slides, GDC 2008 by file name)
URL: https://www.slideshare.net/naughty_dog/creating-a-character-in-uncharted-drakes-fortune (WebFetch)
- slide 34: "Independent Actions – Moving – Breathing – Facial Animations" "Blended together to final pose"
- slide 45: partial neck and spine animations "Made the character look stiff"
- slides 45-46 (additive): "Preserve base animation motion (texture)" "Natural 'swaying' on arms and head" "Arms and head combined in Look-At"

## nucl.ai 2016 talks, summarised by Game Developer ("most inspiring game animation tech talks of 2016")
URL: https://gamedeveloper.com/programming/most-inspiring-game-animation-tech-talks-of-2016 (WebFetch)
- Laurent Delayen (Epic, Paragon): "a system of base animation systems, various layers, and post-processing fix-up effects"; "rather than scaling the playback rate they decided to modify the stride length"; "The hip upward/downward motion is then smoothed out via springs."
- Simon Clavet (Ubisoft, For Honor): "In these types of situations it is often better to just slide the character a little."

## Twelve basic principles of animation (Thomas and Johnston, The Illusion of Life, 1981), via Wikipedia
URL: https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation (API extract, curl)
- Follow through: "loosely tied parts of a body should continue moving after the character has stopped and the parts should keep moving beyond the point where the character stopped only to be subsequently 'pulled back' towards the center of mass"
- "'Overlapping action' is the tendency for parts of the body to move at different rates"
- Secondary action: "Adding secondary actions to the main action gives a scene more life ... they emphasize, rather than take attention away from the main action."
- Slow in and slow out: "The movement of objects in the real world ... needs time to accelerate and slow down."
- Squash and stretch: "In realistic animation, however, the most important aspect of this principle is that an object's volume does not change"
- Anticipation: "a character looking off-screen to anticipate someone's arrival, or attention focusing on an object that a character is about to pick up."

## Steve Swink, Game Feel (2009), via Wikipedia
URL: https://en.wikipedia.org/wiki/Game_feel (search summary)
- "real-time control of virtual objects in a simulated space, with interactions emphasised by polish"

## Resting breath rate (for an idle breathing layer)
URL: https://medlineplus.gov/ency/article/002341.htm (MedlinePlus, "Vital signs", curl)
- "Normal vital sign ranges for the average healthy adult while resting are: ... Breathing: 12 to 18 breaths per minute Pulse: 60 to 100 beats per minute"

## Death Stranding (see sound-games.md): lean and sway, then readjust balance with cargo weight (Yoshiike, 2020).

## Godot 4.7 class reference (raw rst, branch 4.7)
- SpringBoneSimulator3D: "can be used to wiggle hair, cloth, and tails. This modifier behaves differently from PhysicalBoneSimulator3D as it attempts to return the original pose after modification." "it does not support a branched chain" "A scaled SpringBoneSimulator3D will likely not behave as expected." https://raw.githubusercontent.com/godotengine/godot-docs/4.7/classes/class_springbonesimulator3d.rst
- LookAtModifier3D: "rotates a bone to look at a target. This is helpful for moving a character's head to look at the player". "the LookAtModifier3D assigned to the parent bone must be put above the LookAtModifier3D assigned to the child bone". https://raw.githubusercontent.com/godotengine/godot-docs/4.7/classes/class_lookatmodifier3d.rst

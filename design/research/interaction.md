# Using things: how games pick what E does (13 Nov 2026)

Why: the Windows playtest of 13 Nov. Doors offered E at one point outside, off to one side, so a player had to stand
on that spot, and could not open or close a door from inside. Saved sources are in `pages/interaction/`. ✅ means
read in the saved file (checked with `kwic.py`).

| Claim | Status | Source |
|---|---|---|
| Source's `+use` first traces along the view; a usable thing hit there is returned at once ("if this is directly under the cursor just return it now") | ✅ | `source-sdk-2013-baseplayer_shared.cpp`, `FindUseEntity()` |
| It then searches a sphere of `PLAYER_USE_RADIUS` (80 units) round the eye, measures each object at `CalcNearestPoint()` on its collision, rejects `dot < 0.8` with the view, and keeps the one nearest the view line | ✅ | same, and `source-sdk-2013-baseplayer_shared.h` (`#define PLAYER_USE_RADIUS 80.f`) |
| Height is measured against the player's own box (`IntervalDistance` between the hit and the box's bottom and top) | ✅ | same |
| A radius pick is then traced for occlusion: "make sure the object isn't behind glass or a grate" | ✅ | same |
| Minecraft: "Interaction range (also known as reach) is the maximum distance a player can interact with a block or entity"; "When within the reach distance, targeted blocks are highlighted" | ✅ | `minecraft-interaction-range.html` |
| Minecraft reach: Java blocks 4.5, entities 3; Bedrock 5 on keyboard, mouse or controller, 6 on touch | ✅ | `minecraft-interaction-range.html`, `minecraft-attribute.html` (`block_interaction_range` default 4.5) |
| Game Accessibility Guidelines: "Ensure interactive elements / virtual controls are large and well spaced, particularly on small or touch screens" | ✅ | `gag-full.html` |
| The Valve wiki's unit size page could not be saved (a bot check), so no metre value of 80 units is used | n/a | |

What we took (`sandbox/interactions.gd`, skills/character-body "Using things"): reach to the nearest point of the
thing's collision box from either side; an open door also counts at its doorway; no prompt through a wall; first person
picks what the view rests on, then the shape nearest the view line inside Source's `dot >= 0.8` cone (74 degrees across);
third person the same round the heading; the current target is favoured by a few degrees so the prompt does not flicker.

# The ride home: NASA's two-crew Mars Ascent Vehicle (MAV) standing on the descent stage that landed it, which is
# its launch platform ("relies on the EDL element to act as a launch platform"). Sizes from NASA's 2021 MAV paper
# (NTRS 20210026439, research/junior-astronaut/pages/base-gap/): overall 4.5 m wide and 7.2 m tall (figure 1 labels,
# read as width and height), four main engines on stage 1, one on stage 2; the crew cabin "a vertical cylinder
# 2.3 m in diameter and 2.9 m tall" with an axial docking system on top and "a radial mounted 1 m square hatch".
# It lands a launch window before the crew and is filled on the ground; the crew "will not be cleared to land on
# Mars until the full propellant compliment required for powered ascent is confirmed": the gauge on stage 1 is
# full and lit. Plain: no flags, no logos, the team's name only.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/building_mav.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

DECK, PAD, K = 2.85, 3.0, 1.15  # deck top, footpad radius, the descent stage widened under a 4.5 m stage
R1, R2, RC = 2.25, 1.5, 1.15    # stage 1, stage 2's propulsion section, the cabin (2.3 m)
BELL, S1, GAP, S2, CAB = 0.6, 2.7, 0.3, 0.7, 2.9  # heights: 0.6 + 2.7 + 0.3 + 0.7 + 2.9 = 7.2 m
z1 = DECK + 0.15 + BELL          # stage 1's bottom: the bells hang under it, clear of the deck
z2 = z1 + S1 + GAP               # stage 2's bottom
zc = z2 + S2                     # the cabin's floor
reset()

body = descent_stage(DECK, PAD, K)
for i in range(4):  # the launch stand: four posts from the deck to stage 1, between the engines
    a = 90 * i
    body.append(smooth(bar(f"stand{i}", at(1.9, a, DECK - 0.05), at(1.9, a, z1 + 0.05), 0.09, mat("metal"), 12)))
join("mav-col", body)

# the vehicle that lifts off: both stages and the cabin, one node `ascent` (data/world.json `moving`, so it is not
# merged into the still cell and cine.gd launch() can fly it), its origin at its base, the bells' mouths. The
# descent stage and the launch stand stay on the ground: it "relies on the EDL element to act as a launch platform"
up = [smooth(bevel(cyl("stage1", R1, S1, (0, 0, z1 + S1 / 2), mat("body"), 48), width=0.04)),
      smooth(cone("interstage", R1 - 0.05, R2, (0, 0, z1 + S1 + GAP / 2), mat("trim"), 48)),
      smooth(bevel(cyl("stage2", R2, S2, (0, 0, z2 + S2 / 2), mat("trim"), 40), width=0.03)),
      smooth(bevel(cyl("cabin", RC, CAB, (0, 0, zc + CAB / 2), mat("body"), 40), width=0.05))]
for i in range(4):  # stage 1's main engines
    up.append(smooth(cone(f"bell{i}", 0.34, 0.16, at(1.05, 45 + 90 * i, z1 - BELL / 2), mat("metal"), 20, rot=(math.pi, 0, 0))))
up.append(smooth(cone("bell_s2", 0.3, 0.14, (0, 0, z2 - 0.05), mat("metal"), 20, rot=(math.pi, 0, 0))))  # in the interstage
for z in (z1 + 0.12, z1 + S1 / 2, z1 + S1 - 0.12):
    up.append(smooth(cyl(f"band{z:.2f}", R1 + 0.012, 0.08, (0, 0, z), mat("trim"), 48)))
for z in (zc + 0.08, zc + CAB - 0.08):
    up.append(smooth(cyl(f"cab_band{z:.2f}", RC + 0.012, 0.08, (0, 0, z), mat("trim"), 40)))
for i in range(4):  # stage 2's thruster blocks round the cabin's top
    t = bevel(box(f"rcs{i}", (0.16, 0.3, 0.3), at(RC + 0.07, 45 + 90 * i, zc + CAB - 0.45), mat("trim")), width=0.02)
    t.rotation_euler.z = math.radians(45 + 90 * i)
    up.append(t)
up.append(smooth(bevel(cyl("docking", 0.6, 0.22, (0, 0, zc + CAB + 0.11), mat("metal"), 32), width=0.02)))

# the 1 m square side hatch on the front, two small windows beside it
up.append(smooth(bevel(box("hatch", (1.0, 0.1, 1.0), (0, RC - 0.02, zc + 1.2), mat("trim")), width=0.03)))
for s in (-1, 1):
    up.append(smooth(cyl(f"window{s}", 0.12, 0.08, at(RC, 90 + s * 40, zc + 1.9), mat("glass"), 16, rot=(math.radians(90), 0, math.radians(s * 40)))))

# the fuel gauge on stage 1's front: a full bar, lit, under raised letters (colour is never the only sign)
GZ = z1 + 0.6
up.append(bevel(box("gauge", (0.42, 0.12, 1.5), (0, R1 + 0.03, GZ + 0.75), mat("trim")), width=0.02))
up.append(box("fuel_full", (0.26, 0.04, 1.32), (0, R1 + 0.1, GZ + 0.75), mat("light")))
for k in range(1, 4):  # quarter marks over the bar
    up.append(box(f"tick{k}", (0.34, 0.03, 0.025), (0, R1 + 0.125, GZ + 0.09 + 0.33 * k), mat("trim")))
up.append(wrap(flat_label("fuel_label", "FUEL FULL", 0.3, (0, 0, 0), "trim", 0.02, 180), R1, 90, GZ + 1.8))
up.append(wrap(flat_label("team_label", "CLAMOR", 0.32, (0, 0, 0), "trim", 0.02, 180), R1, 270, z1 + S1 / 2 + 0.5))
settle(join("ascent", up), (0, 0, z1 - BELL))
done("building_mav")

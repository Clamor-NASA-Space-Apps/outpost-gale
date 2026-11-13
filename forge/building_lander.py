# The crew lander: the descent stage that brought the pressurised rover down, now an empty deck with the rover's
# tie-down rails and the crew's logistics cans (NASA's 30-sol plan: "a pressurized rover, a docking adapter, and
# crew consumables", SAC21, NTRS 20210026448). The ride home stands on its own lander (building_mav.py), so this one
# carries no rocket. About 6 m across the footpads. A porch and a ladder at the front reach the ground. Plain: no
# flags, no logos.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/building_lander.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

DECK, PAD = 2.85, 2.6   # deck top height, footpad radius from the centre
reset()

body = descent_stage(DECK, PAD)
for s in (-1, 1):  # the rover's tie-down rails, empty since it drove off
    body.append(bevel(box(f"rail{s}", (0.16, 3.4, 0.12), (s * 0.9, -0.2, DECK + 0.05), mat("metal")), width=0.02))
    body.append(bevel(box(f"chock{s}", (0.3, 0.2, 0.22), (s * 0.9, -1.85, DECK + 0.09), mat("hazard")), width=0.02))
join("lander-col", body)
# two logistics cans still to unload, the third one became the trash can by the pad (prop_trash_can)
splc("splc_a-col", -0.7, 1.05, DECK)
splc("splc_b-col", 0.7, 1.05, DECK)

porch(DECK, 2.0)
done("building_lander")

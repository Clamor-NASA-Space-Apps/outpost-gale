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
# two logistics cans still to unload, the third one became the trash can by the pad (prop_trash_can). Each says what
# it holds (the plan's crew consumables: food, and water, which the first stay brings rather than recycles, ICES-2023-265),
# and the deck says what it is: players took the cans on legs for a crashed rocket (14 Nov playtest)
for name, x, word in (("splc_a-col", -0.7, "FOOD"), ("splc_b-col", 0.7, "WATER")):
    splc(name, x, 1.05, DECK)
    # on the front, toward the base, turned a little to the can's outer side so the pair also reads from either flank;
    # a second label each side broke the building budget (15,322 of 15,000 triangles)
    wrap(flat_label(f"{name[:6]}_{word}", word, 0.24, (0, 0, 0), "trim", 0.015, 180), SPLC_R, 90 - 40 * (x > 0) + 40 * (x < 0), DECK + 0.68).location = (x, 1.05, 0)
for a in (67.5, 157.5, 247.5, 337.5):  # on every other equipment bay's face, one each way round
    flat_label(f"lander_label{a}", "LANDER", 0.2, at(2.07 + 0.003, a, DECK - 0.27), "trim", 0.006, a - 90)

porch(DECK, 2.0)
done("building_lander")

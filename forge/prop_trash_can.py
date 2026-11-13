# The trash can: an emptied logistics can (base_kit splc()), filled with the crew's trash and parked by the crew
# lander for good. NASA's 30-sol plan: "the empty SPLC would be filled with trash" and parked "next to the lander as
# its permanent disposal location" (SAC21, NTRS 20210026448); planetary protection asks for "double layer
# containment", "a single site" and a "50+ year container design life" (ICES-2023-361): two seal bands, one spot.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_trash_can.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

reset()
splc("can-col", 0, 0, 0)
smooth(cyl("seal", SPLC_R + 0.02, 0.1, (0, 0, SPLC_H - 0.45), mat("hazard"), 32))  # the second seal, taped round
wrap(flat_label("trash_label", "TRASH", 0.2, (0, 0, 0), "trim", 0.015, 180), SPLC_R, 90, 0.62)
done("prop_trash_can")

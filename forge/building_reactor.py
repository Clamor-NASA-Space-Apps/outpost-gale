# The fission surface power unit on the horizon: 10 kWe in NASA's first-stay plan (SAC21), put about 1 km from the
# crew so the dose there stays "<5 rem/yr at 1 km" and joined to them by a 3 kVac cable (NTRS 20250000841). The
# stack follows that 2025 design, stowed "4m dia. x 6m length": the reactor low on a landed frame, a shadow
# shield above it toward the crew, the power converters, then radiator wings on the mast. That design is 40 kWe
# with 140 to 180 m2 of radiator; ours is a quarter of it, four wings of 1.8 x 5 m (36 m2, our scaling). A
# flashing obstruction light on top (node `beacon`, world.json blink; -col keeps it out of the joined detail),
# hazard bands on the legs.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

DECK, R = 1.2, 2.0           # frame deck height, frame radius (4 m across, the stowed diameter)
reset()

parts = []
for i in range(4):  # landing frame: four legs with pads, a deck ring
    a = 45 + 90 * i
    parts.append(smooth(bar(f"leg{i}", at(R * 0.7, a, DECK), at(R, a, 0.1), 0.07, mat("metal"))))
    parts.append(smooth(cyl(f"pad{i}", 0.3, 0.1, at(R, a, 0.05), mat("metal"), 16)))
    parts.append(smooth(cyl(f"leg_band{i}", 0.075, 0.12, at(R * 0.85, a, DECK * 0.55), mat("hazard"), 8)))
deck = cyl("deck", R * 0.75, 0.15, (0, 0, DECK), mat("trim"), 24)
parts.append(bevel(deck, width=0.03, segments=1))
parts.append(smooth(cyl("vessel", 0.55, 1.3, (0, 0, DECK + 0.72), mat("metal"), 24)))           # the reactor
parts.append(smooth(cone("shield", 1.4, 0.8, (0, 0, DECK + 1.35), mat("trim"), 32)))           # shadow shield
parts.append(smooth(cyl("converters", 0.8, 1.2, (0, 0, DECK + 2.7), mat("body"), 24)))          # Brayton units
for s in (-1, 1):
    parts.append(bevel(box(f"converter_box{s}", (0.5, 0.35, 0.8), (s * 0.85, 0, DECK + 2.6), mat("body")), width=0.03, segments=1))
parts.append(smooth(bar("mast", (0, 0, DECK + 3.3), (0, 0, DECK + 9.1), 0.12, mat("metal"), 16)))
for i in range(4):  # radiator wings, edge-on to the mast, each on two struts
    a = 90 * i
    w = box(f"radiator{i}", (1.8, 0.06, 5.0), at(1.1, a, DECK + 6.2), mat("metal"))
    w.rotation_euler.z = math.radians(a)
    parts.append(bevel(w, width=0.02, segments=1))
    for z in (DECK + 4.2, DECK + 8.2):
        parts.append(bar(f"strut{i}{z}", at(0.1, a, z), at(0.25, a, z), 0.05, mat("metal")))
    for k in range(4):  # coolant headers across each wing
        h = box(f"header{i}{k}", (1.82, 0.09, 0.05), at(1.1, a, DECK + 4.0 + k * 1.45), mat("trim"))
        h.rotation_euler.z = math.radians(a)
        parts.append(h)
parts.append(smooth(cyl("mast_cap", 0.18, 0.12, (0, 0, DECK + 9.16), mat("trim"), 16)))
join("body-col", parts)
smooth(sphere("beacon-col", 0.1, (0, 0, DECK + 9.3), mat("light"), 12))
# the 3 kVac line leaves from the deck's rim on the front (+Y, toward the crew), between two legs, down a conduit
# into a ground gland box where the long field cable plugs in (world.json cables.ends)
port("port_1", (0, R * 0.75 + 0.3), (0, R * 0.75, DECK - 0.02), r=0.04, size=(0.2, 0.2))
done("building_reactor")

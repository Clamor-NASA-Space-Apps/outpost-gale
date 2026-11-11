# The battery bank: a battery cabinet on a steel skid, sized like a stationary battery rack (1.6 m long,
# 0.8 m deep, 1.2 m tall: the world.json footprint). Three module doors, vents, a POWER sign, a status light.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

W, D, SK, CH = 1.6, 0.8, 0.12, 0.98   # length, depth, skid height, cabinet height
reset()

body = skid(W, D, SK)
body.append(bevel(box("cabinet", (W - 0.06, D - 0.1, CH), (0, 0, SK + CH / 2), mat("body")), width=0.03))
body.append(bevel(box("roof", (W, D - 0.02, 0.06), (0, 0, SK + CH + 0.03), mat("trim")), width=0.02))
join("cabinet-col", body)

front = D / 2 - 0.05
for i, x in enumerate((-0.5, 0, 0.5)):  # three module doors, each with a vent grille and a handle
    box(f"door_seam{i}", (0.012, 0.01, CH - 0.32), (x - 0.25, front + 0.004, SK + 0.43), mat("trim"))
    for k in range(5):
        box(f"vent{i}{k}", (0.3, 0.012, 0.018), (x, front + 0.005, SK + 0.22 + k * 0.045), mat("trim"))
    smooth(bar(f"handle{i}", (x + 0.17, front + 0.05, SK + 0.4), (x + 0.17, front + 0.05, SK + 0.6), 0.012, mat("metal")))
box("door_seam3", (0.012, 0.01, CH - 0.32), (0.75, front + 0.004, SK + 0.43), mat("trim"))
box("hazard_band", (W - 0.06, 0.012, 0.06), (0, front + 0.006, SK + 0.08), mat("hazard"))
box("sign", (0.9, 0.012, 0.2), (-0.15, front + 0.006, SK + CH - 0.13), mat("trim"))
flat_label("power_label", "POWER", 0.15, (-0.15, front + 0.016, SK + CH - 0.13), "body", 0.006)
status_light("power_light", (0.55, front + 0.02, SK + CH - 0.13), (0.2, 0.03, 0.06))

for s in (-1, 1):  # lifting eyes on the roof, a cable gland and conduit down the side into the ground
    for y in (-0.25, 0.25):
        smooth(cyl(f"eye{s}{y}", 0.04, 0.012, (s * 0.68, y, SK + CH + 0.1), mat("metal"), 12, rot=(math.pi / 2, 0, 0)))
box("gland_box", (0.08, 0.25, 0.25), (W / 2 - 0.01, 0, SK + 0.6), mat("trim"))
smooth(bar("conduit", (W / 2 + 0.06, 0, SK + 0.5), (W / 2 + 0.06, 0, 0.02), 0.035, mat("metal")))
smooth(bar("conduit_run", (W / 2 + 0.06, 0, 0.035), (W / 2 + 0.3, 0, 0.035), 0.035, mat("metal")))
done("prop_battery_bank")

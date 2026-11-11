# The oxygen maker: an electrolysis cabinet (splits water into oxygen and hydrogen, as the ISS does) beside
# its oxygen store tank, on one skid. 1.2 x 1.0 m, 1.6 m tall (the world.json footprint). O2 sign, status light.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

W, D, SK = 1.2, 1.0, 0.12
CX, CW, CH = -0.22, 0.7, 1.25     # cabinet centre, width, height
TX, TR, TH = 0.33, 0.24, 1.2      # tank centre, radius, straight height
reset()

body = skid(W, D, SK)
body.append(bevel(box("cabinet", (CW, D - 0.12, CH), (CX, 0, SK + CH / 2), mat("body")), width=0.03))
body.append(bevel(box("cabinet_cap", (CW + 0.03, D - 0.1, 0.05), (CX, 0, SK + CH + 0.025), mat("trim")), width=0.015))
tank = cyl("tank", TR, TH, (TX, 0.05, SK + 0.1 + TH / 2), mat("body"), 32)
body.append(smooth(tank))
for z in (SK + 0.1, SK + 0.1 + TH):  # domed ends
    body.append(smooth(sphere(f"tank_end{z}", TR, (TX, 0.05, z), mat("body"), 24)))
for s in (-1, 1):
    body.append(box(f"saddle{s}", (0.5, 0.06, 0.25), (TX, 0.05 + s * 0.2, SK + 0.12), mat("metal")))
join("body-col", body)

front = (D - 0.12) / 2
for z in (SK + 0.35, SK + 1.05):  # hazard bands on the oxygen tank
    smooth(cyl(f"tank_band{z}", TR + 0.008, 0.05, (TX, 0.05, z), mat("hazard"), 32))
box("front_seam", (0.012, 0.01, CH - 0.2), (CX, front + 0.004, SK + CH / 2), mat("trim"))
for k in range(6):
    box(f"vent{k}", (0.26, 0.012, 0.018), (CX - 0.17, front + 0.005, SK + 0.15 + k * 0.045), mat("trim"))
box("sign", (0.5, 0.012, 0.36), (CX, front + 0.006, SK + 0.92), mat("trim"))
flat_label("o_label", "O", 0.34, (CX + 0.05, front + 0.016, SK + 0.93), "body", 0.006)
flat_label("two_label", "2", 0.17, (CX - 0.1, front + 0.016, SK + 0.84), "body", 0.006)
status_light("o2_light", (CX, front + 0.02, SK + CH - 0.08), (0.3, 0.03, 0.05))
smooth(cyl("gauge", 0.07, 0.04, (CX + 0.17, front + 0.02, SK + 0.4), mat("trim"), 20, rot=(math.pi / 2, 0, 0)))
smooth(cyl("gauge_glass", 0.055, 0.05, (CX + 0.17, front + 0.025, SK + 0.4), mat("glass"), 20, rot=(math.pi / 2, 0, 0)))

# pipes: cabinet to tank, a hydrogen vent stack, and the feed down to the ground (toward the habitat)
smooth(bar("o2_pipe", (CX + CW / 2 - 0.02, -0.25, SK + 1.0), (TX, -0.25, SK + 1.0), 0.025, mat("metal")))
smooth(bar("o2_pipe_drop", (TX, -0.25, SK + 1.0), (TX, -0.2, SK + 1.15), 0.025, mat("metal")))
smooth(bar("vent_stack", (CX - 0.2, -0.3, SK + CH), (CX - 0.2, -0.3, SK + CH + 0.3), 0.03, mat("metal")))
smooth(cyl("vent_cap", 0.05, 0.04, (CX - 0.2, -0.3, SK + CH + 0.32), mat("trim"), 16))
smooth(bar("feed", (-W / 2 - 0.04, -0.3, SK + 0.5), (-W / 2 - 0.04, -0.3, 0.03), 0.03, mat("metal")))
smooth(bar("feed_in", (-W / 2 - 0.04, -0.3, SK + 0.5), (CX - CW / 2, -0.3, SK + 0.5), 0.03, mat("metal")))
done("prop_oxygen_maker")

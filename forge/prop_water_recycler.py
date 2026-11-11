# The water recycler: a processor cabinet (the ISS water loop: filters, then a brine processor) with a clean
# water tank and a smaller brine tank, on one skid. 1.2 x 1.0 m, 1.6 m tall. WATER sign, status light.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

W, D, SK = 1.2, 1.0, 0.12
CX, CW, CH = -0.2, 0.74, 1.35
reset()

body = skid(W, D, SK)
body.append(bevel(box("cabinet", (CW, D - 0.12, CH), (CX, 0, SK + CH / 2), mat("body")), width=0.03))
body.append(bevel(box("cabinet_cap", (CW + 0.03, D - 0.1, 0.05), (CX, 0, SK + CH + 0.025), mat("trim")), width=0.015))
for name, x, y, r, h in (("water_tank", 0.36, -0.18, 0.22, 1.1), ("brine_tank", 0.4, 0.26, 0.13, 0.7)):
    body.append(smooth(cyl(name, r, h, (x, y, SK + h / 2 + 0.02), mat("body" if name == "water_tank" else "trim"), 28)))
    body.append(smooth(cyl(name + "_lid", r * 0.8, 0.06, (x, y, SK + h + 0.05), mat("metal"), 28)))
join("body-col", body)

front = (D - 0.12) / 2
for z in (SK + 0.3, SK + 0.8):
    smooth(cyl(f"water_band{z}", 0.228, 0.04, (0.36, -0.18, z), mat("trim"), 28))
for i in range(3):  # three filter cartridges behind a window strip
    smooth(cyl(f"filter{i}", 0.05, 0.4, (CX - 0.2 + i * 0.13, front + 0.02, SK + 0.42), mat("glass"), 16))
    smooth(cyl(f"filter_cap{i}", 0.06, 0.05, (CX - 0.2 + i * 0.13, front + 0.02, SK + 0.64), mat("metal"), 16))
box("front_seam", (CW - 0.1, 0.01, 0.012), (CX, front + 0.004, SK + 0.75), mat("trim"))
box("sign", (0.66, 0.012, 0.22), (CX, front + 0.006, SK + 0.98), mat("trim"))
flat_label("water_label", "WATER", 0.15, (CX, front + 0.016, SK + 0.98), "body", 0.006)
status_light("water_light", (CX, front + 0.02, SK + CH - 0.1), (0.3, 0.03, 0.05))
smooth(cyl("gauge", 0.06, 0.04, (CX + 0.25, front + 0.02, SK + 0.42), mat("trim"), 20, rot=(math.pi / 2, 0, 0)))
smooth(cyl("gauge_glass", 0.045, 0.05, (CX + 0.25, front + 0.025, SK + 0.42), mat("glass"), 20, rot=(math.pi / 2, 0, 0)))

# pipe loop: cabinet to both tanks, and the line down to the ground toward the habitat
smooth(bar("clean_pipe", (CX + CW / 2 - 0.02, -0.18, SK + 1.05), (0.36, -0.18, SK + 1.05), 0.025, mat("metal")))
smooth(bar("brine_pipe", (CX + CW / 2 - 0.02, 0.26, SK + 0.55), (0.4, 0.26, SK + 0.55), 0.02, mat("metal")))
smooth(bar("feed", (-W / 2 - 0.04, 0.3, SK + 0.5), (-W / 2 - 0.04, 0.3, 0.03), 0.03, mat("metal")))
smooth(bar("feed_in", (-W / 2 - 0.04, 0.3, SK + 0.5), (CX - CW / 2, 0.3, SK + 0.5), 0.03, mat("metal")))
done("prop_water_recycler")

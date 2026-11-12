# A fixed solar wing for the big field: NASA's Mars base study lays its arrays as wings "2.5 m high x 58 m long",
# "inclined 30 degrees" (DRA 5.0 Addendum; data/reality.json solar.wing.height). Ours is 40 m long, so six rows
# give 600 m2, about the 580 m2 a 10 kW base needs on solar (design/research/missing-assets.md 2f). Same tube
# height, panel width and tilt as building_solar_array.py, but it never turns: one still mesh the world merges,
# where the tracking arrays' panels each cost a draw call. The cells are one node, `cells`, with the panel gaps
# laid over them; all of it takes the dust coat (a fixed field nobody sweeps, as InSight's panels).
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

AX, L, W, TILT, LONG = 1.45, row("solar.wing.height"), 1.45, 30, 40.0  # tube height, wing depth, panel width, tilt, length
N = int(LONG / W)                                                    # panels along the wing
reset()

cells = box("cells-col", (N * W - 0.04, L - 0.04, 0.03), (0, 0, AX + 0.06), mat("glass"))
top = [box("rail_front", (N * W, 0.04, 0.06), (0, L / 2 - 0.02, AX + 0.05), mat("metal")),
       box("rail_back", (N * W, 0.04, 0.06), (0, -L / 2 + 0.02, AX + 0.05), mat("metal"))]
for k in range(1, N):  # gaps between panels, 4 mm proud of the cells top and bottom
    top.append(box(f"gap{k}", (0.03, L - 0.09, 0.038), (-N * W / 2 + k * W, 0, AX + 0.06), mat("trim")))
for s in (-1, 1):  # ribs under the cells
    top.append(box(f"rib{s}", (N * W - 0.1, 0.05, 0.05), (0, s * 0.6, AX + 0.01), mat("trim")))
top.append(box("strings", (N * W - 0.09, 0.012, 0.038), (0, 0, AX + 0.06), mat("trim")))
for o in [cells] + top:  # turn the whole face about the tube axis
    settle(o, (0, 0, AX))
    o.rotation_euler.x = math.radians(-TILT)
join("face", top)

frame = [smooth(cyl("tube", 0.06, N * W, (0, 0, AX), mat("metal"), 12, rot=(0, math.pi / 2, 0)))]
for i in range(9):  # a post every 5 m
    x = -LONG / 2 + 0.3 + i * (LONG - 0.6) / 8
    frame.append(box(f"post{i}", (0.12, 0.12, AX - 0.06), (x, 0, (AX - 0.06) / 2), mat("metal")))
    frame.append(box(f"footing{i}", (0.45, 0.45, 0.12), (x, 0, 0.06), mat("rock")))
    for s in (-1, 1):
        frame.append(bar(f"brace{i}{s}", (x, s * 0.7, 0.03), (x, 0, AX * 0.6), 0.025, mat("metal")))
join("frame-col", frame)
done("building_solar_wing")

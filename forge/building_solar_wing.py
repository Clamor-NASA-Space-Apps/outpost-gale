# A solar wing for the big field on a single-axis tracker: NASA's Mars base study lays its arrays as wings "2.5 m
# high x 58 m long" (DRA 5.0 Addendum; data/reality.json solar.wing.height). Ours is 40 m long, so six rows give
# 600 m2, about the 580 m2 a 10 kW base needs on solar (design/research/missing-assets.md 2f). Tube height and panel
# width as building_solar_array.py. A long row turns as one piece about its torque tube, driven at the middle post
# (single-axis trackers, design/research/pages/tracker/), so the whole face is one node, `panel_1`, origin on the tube
# axis: rotating it about X turns the row. It rests at -30 degrees like the arrays' panels; world/machines.gd aims it.
# Each module is a sheet of glass over a dark backsheet with a gap between modules: glass alone (the `glass` role is
# 50% see-through) let the ground show through the row and cast no shadow. Swept clean (`panel_*`, DESIGN.md).
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

AX, L, W, TILT, LONG = 1.45, row("solar.wing.height"), 1.45, 30, 40.0  # tube height, wing depth, module width, rest tilt, length
N = int(LONG / W)                                                    # modules along the wing
HALF = N * W / 2
FACE = 0.1  # the backsheet's underside over the tube's axis: clear of the 6 cm tube and its 9 cm bearings as the face turns
POSTS = [-HALF + 0.3 + i * (2 * HALF - 0.6) / 8 for i in range(9)]  # a post every 5 m
reset()

face = [bevel(box("backsheet", (N * W, L, 0.03), (0, 0, AX + FACE + 0.015), mat("trim")), width=0.01, segments=1)]
for k in range(N):  # the glass 5 mm over the backsheet, 3 cm apart: the gaps show the dark backsheet
    face.append(box(f"glass{k}", (W - 0.03, L - 0.1, 0.008), (-HALF + (k + 0.5) * W, 0, AX + FACE + 0.039), mat("glass")))
# aluminium frame rails along both long edges and across both ends, wrapping the backsheet's edge (no strip of it
# left showing under them), the ends buried in the rails
for s in (-1, 1):
    face.append(box(f"rail{s}", (N * W + 0.08, 0.05, 0.06), (0, s * (L / 2 - 0.015), AX + FACE + 0.025), mat("metal")))
    face.append(box(f"end{s}", (0.05, L - 0.06, 0.06), (s * (HALF + 0.02), 0, AX + FACE + 0.025), mat("metal")))
    face.append(box(f"rib{s}", (N * W - 0.1, 0.05, 0.05), (0, s * 0.6, AX + FACE - 0.015), mat("trim")))  # into the backsheet
for i, x in enumerate(POSTS):
    face.append(box(f"clamp{i}", (0.5, 0.18, FACE + 0.02), (x, 0, AX + FACE / 2), mat("metal")))  # tube to backsheet
p = settle(join("panel_1", face), (0, 0, AX))
p.rotation_euler.x = math.radians(-TILT)

frame = [smooth(cyl("tube", 0.06, N * W + 0.4, (0, 0, AX), mat("metal"), 16, rot=(0, math.pi / 2, 0)))]
for i, x in enumerate(POSTS):
    frame.append(bevel(box(f"post{i}", (0.12, 0.12, AX - 0.06), (x, 0, (AX - 0.06) / 2), mat("metal"))))
    frame.append(smooth(cyl(f"bearing{i}", 0.09, 0.14, (x + 0.33, 0, AX), mat("trim"), 16, rot=(0, math.pi / 2, 0))))
    frame.append(bevel(box(f"footing{i}", (0.45, 0.45, 0.12), (x, 0, 0.06), mat("rock"))))
    for s in (-1, 1):
        frame.append(bar(f"brace{i}{s}", (x, s * 0.7, 0.1), (x, 0, AX * 0.6), 0.025, mat("metal")))
        frame.append(box(f"brace_foot{i}{s}", (0.2, 0.2, 0.04), (x, s * 0.7, 0.02), mat("metal")))
# the slew drive hangs under the tube beside the middle post, where no part of the turning face reaches
frame.append(bevel(box("drive", (0.3, 0.3, 0.24), (POSTS[4] + 0.6, 0, AX - 0.24), mat("trim")), width=0.02))
join("frame-col", frame)

# the row's junction box at its north end (-X), on a post, where the field's header cable passes (data/world.json)
JX = -HALF - 0.45
box_ = [bevel(box("junction", (0.25, 0.5, 0.6), (JX, 0, 0.5), mat("body")), width=0.02),
        box("junction_post", (0.08, 0.08, 0.25), (JX, 0, 0.1), mat("metal")),
        bar("lead", (JX + 0.1, 0, 0.4), (-HALF + 0.3, 0, AX - 0.1), 0.02, mat("trim"))]
join("junction-col", box_)
done("building_solar_wing")

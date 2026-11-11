# A ground-mounted solar wing on a single-axis tracker: four panels, 2.5 m long down the slope (the wing
# height in NASA's Mars base study, data/reality.json solar.wing.height), on a torque tube 1.45 m up.
# Each panel is its own node, panel_1..panel_4, with its origin on the tube axis: rotating it about its
# X axis tilts it. They rest at rotation.x = -30 degrees (the study's 30 degree incline), facing the front.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

AX, L, W, TILT = 1.45, 2.5, 1.45, 30     # tube height, panel length and width, rest tilt
XS = (-2.375, -0.825, 0.825, 2.375)      # panel centres: a 0.2 m gap at the middle post
reset()

for i, x in enumerate(XS, 1):
    parts = [bevel(box(f"cells{i}", (W - 0.04, L - 0.04, 0.03), (x, 0, AX + 0.06), mat("glass")), width=0.01, segments=1)]
    for s in (-1, 1):  # aluminium frame
        parts.append(box(f"rail{i}{s}", (0.04, L, 0.06), (x + s * (W / 2 - 0.02), 0, AX + 0.05), mat("metal")))
        parts.append(box(f"end{i}{s}", (W, 0.04, 0.06), (x, s * (L / 2 - 0.02), AX + 0.05), mat("metal")))
        parts.append(box(f"rib{i}{s}", (0.05, L - 0.1, 0.05), (x + s * 0.4, 0, AX + 0.015), mat("trim")))
    for k in range(1, 6):  # gaps between cell strings
        parts.append(box(f"string{i}{k}", (W - 0.06, 0.012, 0.034), (x, -L / 2 + k * L / 6, AX + 0.062), mat("trim")))
    parts.append(box(f"busbar{i}", (0.012, L - 0.06, 0.034), (x, 0, AX + 0.062), mat("trim")))
    parts.append(box(f"clamp{i}", (0.5, 0.18, 0.08), (x, 0, AX), mat("metal")))
    p = settle(join(f"panel_{i}", parts), (x, 0, AX))
    p.rotation_euler.x = math.radians(-TILT)

frame = [smooth(cyl("tube", 0.06, 6.4, (0, 0, AX), mat("metal"), 16, rot=(0, math.pi / 2, 0)))]
for x in (-3.15, 0, 3.15):
    frame.append(bevel(box(f"post{x}", (0.12, 0.12, AX - 0.06), (x, 0, (AX - 0.06) / 2), mat("metal"))))
    frame.append(smooth(cyl(f"bearing{x}", 0.11, 0.14, (x, 0, AX), mat("trim"), 16, rot=(0, math.pi / 2, 0))))
    frame.append(bevel(box(f"footing{x}", (0.45, 0.45, 0.12), (x, 0, 0.06), mat("rock"))))
    for s in (-1, 1):
        frame.append(bar(f"brace{x}{s}", (x, s * 0.7, 0.1), (x, 0, AX * 0.6), 0.025, mat("metal")))
        frame.append(box(f"brace_foot{x}{s}", (0.2, 0.2, 0.04), (x, s * 0.7, 0.02), mat("metal")))
frame.append(bevel(box("drive", (0.3, 0.3, 0.32), (0, -0.2, AX - 0.12), mat("trim")), width=0.02))
join("frame-col", frame)

# cable tray along the back to a junction box with a status light
tray = [box("tray", (6.2, 0.2, 0.08), (0, -1.2, 0.18), mat("metal"))]
for x in (-3, -1, 1, 3):
    tray.append(box(f"tray_leg{x}", (0.05, 0.05, 0.16), (x, -1.2, 0.08), mat("metal")))
tray.append(bevel(box("junction", (0.5, 0.25, 0.6), (3.6, -1.2, 0.5), mat("body")), width=0.02))
tray.append(box("junction_post", (0.08, 0.08, 0.25), (3.6, -1.2, 0.1), mat("metal")))
join("tray-col", tray)
status_light("junction_light", (3.6, -1.06, 0.72), (0.14, 0.04, 0.05))
done("building_solar_array")

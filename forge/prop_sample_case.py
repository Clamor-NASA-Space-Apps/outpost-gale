# The field sample case: a hard shell case the crew set down at a sample site. A pebble goes in by tongs, into a
# sealed tube, and the tube into the case's foam (design/plans/event-ready.md: "tongs into a sealed tube, tubes
# into the sample case"; NASA wants samples "in sealed sample containers", research/junior-astronaut/base-gap.md).
# Size is ours (no NASA drawing found): 0.46 x 0.34 x 0.18 m, a small hard case two gloves can carry.
# The lid is its own node `lid`, its origin on the hinge along the back (-Y), so the game opens it about X
# (sandbox/interactions.gd verb `turn`). The front, with the latches, faces +Y.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_sample_case.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math  # noqa: E402

from shapes import bar, bevel, box, cyl, finish, join, mat, reset, settle, smooth  # noqa: E402

reset()
BODY, TRIM, METAL, GLASS, ACCENT = (mat(n) for n in ("body", "trim", "metal", "glass", "accent"))
L, W, H, LH = 0.46, 0.34, 0.13, 0.05  # length (x), depth (y), base height, lid height

# the base: a white shell round its edges, a dark rim where the lid closes, dark foam inside holding the tubes
base = [smooth(bevel(box("shell", (L, W, H), (0, 0, H / 2), BODY), width=0.02, segments=3))]
base.append(bevel(box("rim", (L + 0.006, W + 0.006, 0.014), (0, 0, H - 0.004), TRIM), width=0.004, segments=1))
base.append(box("foam", (L - 0.04, W - 0.04, 0.012), (0, 0, H + 0.005), TRIM))
for i in range(4):  # four sealed tubes lying in the foam, half sunk; a fifth place left empty
    x = -0.17 + i * 0.075
    base.append(smooth(cyl(f"tube{i}", 0.012, 0.11, (x, 0.0, H + 0.01), GLASS, 12, rot=(math.pi / 2, 0, 0))))
    base.append(smooth(cyl(f"tube_cap{i}", 0.014, 0.016, (x, 0.062, H + 0.01), METAL, 12, rot=(math.pi / 2, 0, 0))))
for s in (-1, 1):  # two latches on the front, a carry handle on top of the front edge
    base.append(bevel(box(f"latch{s}", (0.05, 0.016, 0.05), (s * 0.13, W / 2 + 0.006, H - 0.02), METAL), width=0.004, segments=1))
    base.append(bevel(box(f"foot{s}", (L - 0.06, 0.03, 0.008), (0, s * (W / 2 - 0.05), 0.004), TRIM), width=0.002, segments=1))
base.append(box("tag", (0.1, 0.006, 0.035), (0, W / 2 + 0.002, H / 2), ACCENT))  # the cool accent: a thing to use
join("case", base)

# the lid, on its hinge along the back edge
lid = [smooth(bevel(box("lid_shell", (L, W, LH), (0, 0, H + 0.006 + LH / 2), BODY), width=0.02, segments=3))]
lid.append(bevel(box("lid_rim", (L + 0.006, W + 0.006, 0.012), (0, 0, H + 0.0135), TRIM), width=0.004, segments=1))
lid.append(smooth(bar("handle", (-0.08, W / 2 - 0.05, H + LH + 0.02), (0.08, W / 2 - 0.05, H + LH + 0.02), 0.008, METAL)))
for x in (-0.08, 0.08):
    lid.append(box(f"handle_post{x}", (0.012, 0.012, 0.03), (x, W / 2 - 0.05, H + LH + 0.006), METAL))
for x in (-0.15, 0.15):
    lid.append(smooth(cyl(f"hinge{x}", 0.008, 0.06, (x, -W / 2 - 0.004, H + 0.006), METAL, 8, rot=(0, math.pi / 2, 0))))
settle(join("lid", lid), (0, -W / 2, H + 0.006))
finish("prop_sample_case")

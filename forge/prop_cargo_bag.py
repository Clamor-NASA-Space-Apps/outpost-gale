# A NASA Cargo Transfer Bag (single CTB: 0.50 x 0.42 x 0.25 m, NTRS 20160002631): soft white fabric,
# zip lid, webbing handles on top and both ends, a label patch. Long side runs along Y.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_cargo_bag.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shapes import bar, bevel, box, finish, mat, reset, smooth  # noqa: E402

reset()
SUIT, TRIM, BODY, ACCENT, METAL = (mat(n) for n in ("suit", "trim", "body", "accent", "metal"))

# Fabric over a soft frame: big round edges, so it reads as cloth and not as a crate
smooth(bevel(box("bag-convcol", (0.42, 0.5, 0.25), (0, 0, 0.125), SUIT), width=0.045, segments=3), 60)
bevel(box("zip", (0.428, 0.508, 0.01), (0, 0, 0.2), TRIM), width=0.004, segments=1)
bar("zip_pull", (0.17, 0.254, 0.2), (0.17, 0.285, 0.2), 0.006, METAL, 6)
# Webbing: one loop handle on top, one on each end
for x in (-0.07, 0.07):
    box(f"strap_top{x}", (0.03, 0.2, 0.006), (x, 0, 0.253), TRIM)
box("handle_top", (0.17, 0.035, 0.012), (0, 0, 0.262), TRIM)
for y in (-0.255, 0.255):
    box(f"handle_end{y}", (0.16, 0.008, 0.035), (0, y * 1.04, 0.15), TRIM)
    for x in (-0.07, 0.07):
        box(f"tab{y}{x}", (0.03, 0.012, 0.05), (x, y, 0.15), TRIM)
# Label patch with an accent tab: a carriable thing, so the one cool colour marks it as usable
bevel(box("label", (0.004, 0.2, 0.1), (0.212, 0.04, 0.12), BODY), width=0.01, segments=1)
box("label_tab", (0.005, 0.05, 0.1), (0.213, -0.09, 0.12), ACCENT)
finish("prop_cargo_bag")

# The sample return box: a sealed aluminium case the crew carry by hand to the ascent vehicle. Apollo's rock box was
# a 7075 aluminium case with silicone rubber seals (Smithsonian NASM record, search summary); a fit-check unit is
# listed at about 19 x 11.5 x 8 in (an auction listing, reported only), so 0.48 x 0.29 x 0.20 m. The MAV allows
# "100 kg ... to encompass scientific sample return and any stowage systems" (NTRS 20210026439). Long side along Y.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_sample_box.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

L, W, H = 0.48, 0.29, 0.20
reset()
smooth(bevel(box("case-convcol", (W, L, H), (0, 0, H / 2), mat("metal")), width=0.015, segments=2))
bevel(box("seal", (W + 0.01, L + 0.01, 0.02), (0, 0, H * 0.72), mat("trim")), width=0.004, segments=1)  # the lid's seam
for y in (-0.13, 0.13):  # two latches over the seam on the front
    bevel(box(f"latch{y}", (0.012, 0.05, 0.07), (W / 2 + 0.008, y, H * 0.72), mat("trim")), width=0.003, segments=1)
for y in (-0.1, 0.1):
    bar(f"handle_post{y}", (0, y, H), (0, y, H + 0.04), 0.008, mat("metal"))
bar("handle", (0, -0.1, H + 0.04), (0, 0.1, H + 0.04), 0.012, mat("trim"))
# the label patch with the accent tab: a thing you can carry, marked the way the cargo bags are
bevel(box("patch", (0.004, 0.2, 0.06), (W / 2 + 0.002, 0.0, H * 0.38), mat("body")), width=0.008, segments=1)
box("patch_tab", (0.005, 0.04, 0.06), (W / 2 + 0.003, -0.125, H * 0.38), mat("accent"))
label("samples", "SAMPLES", 0.03, (W / 2 + 0.0045, 0.0, H * 0.38), (math.pi / 2, 0, math.pi / 2), mat("trim"), 0.0015)
done("prop_sample_box")

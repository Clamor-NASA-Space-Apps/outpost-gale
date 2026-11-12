# A wind telltale after Phoenix's (2008): a light tube hanging on fibres from a gallows on top of a met mast,
# whose tilt in camera pictures gave the wind (data/world.json `telltale`, design/research/pages/alive/telltale.md).
# The real tube is 28 mm long; this one is about ten times that so it reads from the play camera. The tube and
# its fibres are one node, `tell`, with its origin at the hanging point: rotating it tilts it downwind.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

H, ARM, FIBRE, TUBE = 2.2, 0.4, 0.12, 0.26   # mast height, gallows arm, fibre and tube length
reset()

smooth(bevel(cyl("base", 0.2, 0.04, (0, 0, 0.02), mat("trim"), 24), width=0.012, segments=2))
smooth(cyl("mast-convcol", 0.03, H, (0, 0, H / 2 + 0.04), mat("metal"), 12))
smooth(bevel(cyl("collar", 0.05, 0.05, (0, 0, 0.9), mat("trim"), 16), width=0.01, segments=1))
bar("arm", (0, 0, H), (ARM, 0, H), 0.015, mat("metal"))
bar("brace", (0, 0, H - 0.25), (ARM * 0.6, 0, H), 0.01, mat("metal"))
smooth(sphere("cap", 0.04, (0, 0, H + 0.04), mat("trim"), 12))
smooth(sphere("hook", 0.018, (ARM, 0, H - 0.01), mat("metal"), 8))
# the fibres fan out to the tube's two ends, which a wind tunnel showed keeps it from spinning
tell = [bar(f"fibre{s}", (ARM, 0, H - 0.02), (ARM + s * 0.02, 0, H - 0.02 - FIBRE), 0.003, mat("trim"), 6) for s in (-1, 1)]
tell.append(smooth(cyl("tube", 0.022, TUBE, (ARM, 0, H - 0.02 - FIBRE - TUBE / 2), mat("hazard"), 12)))
settle(join("tell", tell), (ARM, 0, H - 0.02))
done("prop_telltale")

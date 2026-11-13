# The relay antenna: a small UHF antenna that talks to spacecraft passing overhead, which pass the messages on to
# Earth. The Mars Relay Network is "an international constellation of four spacecraft", links "up to 2 Mbps", and a
# surface user lacks "line-of-sight to the Earth for about 12 hours per day" (NASA Science, Mars Relay Network). A
# helix in a short white radome on a post, like the UHF antennas rovers carry; sizes are ours.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_relay_antenna.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

H = 1.35
reset()
smooth(bevel(cyl("base", 0.22, 0.05, (0, 0, 0.025), mat("trim"), 24), width=0.012, segments=2))
smooth(cyl("post-convcol", 0.04, H, (0, 0, H / 2 + 0.05), mat("metal"), 12))
bevel(box("radio", (0.26, 0.16, 0.3), (0, 0.1, 0.75), mat("body")), width=0.012)
status_light("relay_light", (0, 0.195, 0.84), (0.06, 0.04, 0.03))
smooth(bevel(cyl("collar", 0.07, 0.05, (0, 0, H + 0.075), mat("trim"), 16), width=0.008, segments=1))
smooth(bevel(cyl("radome", 0.075, 0.42, (0, 0, H + 0.31), mat("body"), 20), width=0.02, segments=2))
done("prop_relay_antenna")

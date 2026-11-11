# A build pad: 6 x 6 m, 0.15 m thick (a step the hero takes without a ramp), laid as nine 2 m pavers of
# sintered regolith with seams between them, hazard corner marks and four low edge lamps.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

S, T, TILE, GAP = 6.0, 0.15, 2.0, 0.02
reset()

pavers = [bevel(box(f"paver{i}{j}", (TILE - GAP, TILE - GAP, T), ((i - 1) * TILE, (j - 1) * TILE, T / 2), mat("rock")), width=0.02, segments=1)
          for i in range(3) for j in range(3)]
pavers.append(box("bed", (S - 0.04, S - 0.04, T - 0.03), (0, 0, (T - 0.03) / 2), mat("trim")))  # fills the seams below the top
join("pad-col", pavers)
for sx in (-1, 1):
    for sy in (-1, 1):  # an L of hazard paint at each corner, and a low lamp in the corner
        box(f"mark_x{sx}{sy}", (0.8, 0.12, 0.006), (sx * (S / 2 - 0.5), sy * (S / 2 - 0.16), T + 0.003), mat("hazard"))
        box(f"mark_y{sx}{sy}", (0.12, 0.8, 0.006), (sx * (S / 2 - 0.16), sy * (S / 2 - 0.5), T + 0.003), mat("hazard"))
        smooth(cyl(f"lamp_base{sx}{sy}", 0.07, 0.05, (sx * (S / 2 - 0.1), sy * (S / 2 - 0.1), T + 0.025), mat("trim"), 12))
        smooth(cyl(f"lamp{sx}{sy}", 0.045, 0.04, (sx * (S / 2 - 0.1), sy * (S / 2 - 0.1), T + 0.07), mat("light"), 12))
for k in (-1, 1):  # centre ticks on each edge, so a build lines up
    box(f"tick_x{k}", (0.12, 0.5, 0.006), (0, k * (S / 2 - 0.3), T + 0.003), mat("hazard"))
    box(f"tick_y{k}", (0.5, 0.12, 0.006), (k * (S / 2 - 0.3), 0, T + 0.003), mat("hazard"))
done("pad_build")

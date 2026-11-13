# Lettuce in four growth stages, prop_lettuce_1..4: red romaine 'Outredgeous', the lettuce Veggie grew on the ISS
# (VEG-01), as a rosette of upright, cupped leaves with ruffled edges, burgundy blades on a green base and midrib.
# world.gd turns a slot's head into the green variety ('Waldmann's Green', VEG-03) by giving `romaine` the
# `plant` role. Stages by days after sowing, harvest at 33 (factcheck row 29): 1 ~7 d, 2 ~14 d, 3 ~24 d, 4 ~33 d.
# Sizes are real (a harvested romaine head 20 to 30 cm tall and across) times K: a seedling at real size is under
# the prop class's 0.1 m floor, and the game scales every stage by one factor from reality.json lettuce.width.
# Each leaf is a sheet with a back sheet (faces reversed), as the engine culls back faces. Named `interior`
# (DESIGN.md weathering.clean): grown indoors, merged swept onto the room-light layer, casting no shadow.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_lettuce.py
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
from base_kit import *  # noqa: E402,F403

K = 3.4
V = (-1.0, -0.6, -0.22, -0.05, 0.05, 0.22, 0.6, 1.0)  # across a leaf; the narrow middle column is the midrib
# stage: leaves, outer leaf length and width (m, real), outer leaf's lean from upright and bend along it (deg), rows
# (a romaine head is upright: the outer leaves lean out, the heart stands; 13 leaves of 8 rows hold the old
# head's triangle count with frilled edges)
STAGES = {1: (4, 0.045, 0.028, 45, 25, 5), 2: (6, 0.09, 0.055, 40, 35, 6), 3: (9, 0.16, 0.09, 35, 40, 7), 4: (13, 0.24, 0.11, 30, 45, 8)}


def leaf(bm, rows, length, width, phi, lean, bend, crown, rng, red, green):
    """One leaf from the crown: rises at `lean` from upright, bends out along its length, cups inward; a blunt round
    tip, the margin frilled (Outredgeous is a "ruffled" red romaine), the midrib green over its lower part."""
    out, side = (math.cos(phi), math.sin(phi)), (-math.sin(phi), math.cos(phi))
    waves, ph = rng.uniform(3.5, 4.5), rng.uniform(0, 6.3)
    r, z = crown, 0.0
    grid = []
    for i in range(rows):
        u = i / (rows - 1)
        a = math.radians(lean + bend * u * u)
        if i:
            r, z = r + math.sin(a) * length / (rows - 1), z + math.cos(a) * length / (rows - 1)
        # an ellipse from a 25% wide petiole, widest at 60%, closing to a blunt tip (55% wide), rounded below
        hw = width / 2 * max(0.25, math.sqrt(max(0.0, 1 - ((u - 0.6) / 0.62) ** 2)))
        up = (-math.cos(a), math.sin(a))  # the leaf's upper face: toward the head's middle and up
        row_ = []
        for v in V:
            back = (1 - math.sqrt(1 - v * v * 0.9)) * u ** 6 * length * 0.3  # the tip's corners pulled back: round
            frill = math.sin(waves * math.pi * u + ph + 1.5 * v) * u ** 0.7
            lift = hw * (0.2 * abs(v) ** 1.5 + 0.7 * v * v * frill)
            spread = v * hw * (1 + 0.1 * frill * abs(v))
            rr, zz = r - back * math.sin(a), z - back * math.cos(a)
            row_.append(bm.verts.new((K * (rr * out[0] + spread * side[0] + lift * up[0] * out[0]),
                                      K * (rr * out[1] + spread * side[1] + lift * up[0] * out[1]),
                                      K * (zz + lift * up[1]))))
        grid.append(row_)
    for i in range(rows - 1):
        for j in range(len(V) - 1):
            f = bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
            rib = j == 3 and i < rows * 0.75
            f.material_index = green if (rib or i < rows // 5) else red
            f.smooth = True


for n, (count, length, width, lean, bend, rows) in STAGES.items():
    reset()
    rng = random.Random(n)
    me = bpy.data.meshes.new("interior")
    me.materials.append(mat("romaine"))
    me.materials.append(mat("plant"))
    bm = bmesh.new()
    for k in range(count):  # outermost (oldest, longest, most open) first, each 137.5 degrees on from the last
        f = k / max(count - 1, 1)
        leaf(bm, rows, length * (1 - 0.15 * f) * rng.uniform(0.9, 1.05), width * (1 - 0.3 * f),
             math.radians(137.5 * k + rng.uniform(-8, 8)), lean * (1 - 0.85 * f), bend * (1 - 0.6 * f),
             length * 0.08 * (1 - f), rng, 0, 1)
    back = bmesh.ops.duplicate(bm, geom=bm.faces[:])["geom"]
    bmesh.ops.reverse_faces(bm, faces=[g for g in back if isinstance(g, bmesh.types.BMFace)])
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("interior", me)
    bpy.context.scene.collection.objects.link(o)
    done(f"prop_lettuce_{n}", solid=False)  # a plant in a bed blocks nobody

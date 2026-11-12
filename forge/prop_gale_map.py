# A table map of Gale crater for HAB 1's workstation: LPG-3D's "Gale Crater on Mars - printable version" (Gwenael
# Caravaca, LPG Nantes, from NASA/JPL-Caltech/MSSS data; Sketchfab, CC BY-NC 4.0, ASSETS.md), decimated to the prop
# budget, its colour kept at 1024 px (material `gale_photo`, a DESIGN.md kit `keep`), on a dark plinth. A teal pin
# marks the base: 200 m west of Bradbury Landing (4.5895 S, 137.4383 E, design/research), placed from Mount Sharp's
# summit (the highest point near the middle) with an approximate scale and north, so the pin is near, not exact.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_gale_map.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
from base_kit import *  # noqa: E402,F403
from mathutils import Matrix, Vector  # noqa: E402

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), *[".."] * 4, "assets-cache", "sketchfab", "gale_crater_on_mars_-_printable_version")
SIZE, PLINTH, TRIS = 0.56, 0.085, 3300  # map width (m), plinth height, triangles for the map
CRATER = 154.0  # km across Gale's rim; the rim fills about 0.8 of the model's width (by eye)
KM_N, KM_W = 0.49 * 59.16, 0.41 * 59.16 * 0.9965  # the base from Mount Sharp's summit (5.08 S, 137.85 E: an unsourced figure), km north and west
reset()

bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, "scene.gltf"))
bpy.context.view_layer.update()
ms = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in ms:
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
for o in [o for o in bpy.context.scene.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o)
gale = join("gale_map", ms)
bpy.ops.object.select_all(action="DESELECT")
gale.select_set(True)
bpy.context.view_layer.objects.active = gale
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bm = bmesh.new()
bm.from_mesh(gale.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bm.to_mesh(gale.data)
bm.free()
d = gale.modifiers.new("Decimate", "DECIMATE")
d.ratio = TRIS / len(gale.data.polygons)
bpy.ops.object.modifier_apply(modifier=d.name)
# the scan's square lies turned in its own plane: square it to x and y (corner with the least x to the corner with
# the least y is one edge), and take +y as north (not stated by the source)
vs = gale.data.vertices
a, b = min(vs, key=lambda v: v.co.x).co, min(vs, key=lambda v: v.co.y).co
turn = Matrix.Rotation(-math.atan2(b.y - a.y, b.x - a.x), 4, "Z")
for v in vs:
    v.co = turn @ v.co
lo, hi = (Vector([f(v.co[i] for v in gale.data.vertices) for i in range(3)]) for f in (min, max))
k = SIZE / max(hi.x - lo.x, hi.y - lo.y)
mid = (lo + hi) / 2
for v in gale.data.vertices:
    v.co = Vector(((v.co.x - mid.x) * k, (v.co.y - mid.y) * k, (v.co.z - lo.z) * k + PLINTH + 0.001))
peak = max((v for v in gale.data.vertices if v.co.xy.length < SIZE * 0.25), key=lambda v: v.co.z).co.copy()  # Mount Sharp, not the rim
m = gale.data.materials[0]
m.name = "gale_photo"
for n in m.node_tree.nodes:
    if n.type == "TEX_IMAGE" and n.image:
        n.image.scale(1024, 1024)
        path = os.path.join(SRC, "gale_1024.jpg")  # a downsized copy beside the download
        n.image.filepath_raw, n.image.file_format = path, "JPEG"
        n.image.save()
        n.image = bpy.data.images.load(path)
smooth(gale, 45)

bevel(box("plinth", (SIZE + 0.04, SIZE + 0.04, PLINTH), (0, 0, PLINTH / 2), mat("trim")), width=0.01, segments=1)
per_km = SIZE * 0.8 / CRATER
pin = Vector((peak.x - KM_W * per_km, peak.y + KM_N * per_km, 0))
ground = max((v.co.z for v in gale.data.vertices if (v.co.xy - pin.xy).length < 0.01), default=PLINTH)
smooth(bar("pin", (pin.x, pin.y, ground - 0.002), (pin.x, pin.y, ground + 0.05), 0.002, mat("metal")))
smooth(sphere("pin_head", 0.008, (pin.x, pin.y, ground + 0.055), mat("accent"), 10))
done("prop_gale_map", solid=False)  # on the desk, which blocks; the map blocks nobody

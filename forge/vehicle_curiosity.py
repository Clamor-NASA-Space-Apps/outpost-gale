# NASA's Curiosity model (science.nasa.gov, public domain, "NASA/JPL-Caltech") made fit for the game:
# the four insignia medallions in tex_05 painted out (MSL patch, JPL logo, US flag, NASA meatball),
# turned to face +Y here (-Z in glTF), scaled to the press kit's 3.0 m body length (arm not counted),
# decimated to the vehicle budget, origin on the ground. Then, from the project folder:
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=/tmp/cur FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/vehicle_curiosity.py
#   npx --offline @gltf-transform/cli optimize /tmp/cur/vehicle_curiosity.glb models/vehicle_curiosity.glb \
#     --compress false --texture-compress webp --join false --instance false --palette false --simplify false
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import numpy as np  # noqa: E402

from shapes import export_glb, ground_origin, render_previews, reset  # noqa: E402

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "assets-cache", "nasa-3d", "curiosity", "24584_Curiosity_static.glb")
LENGTH, TRIS = 3.0, 9800   # MSL launch press kit: 3.0 m long without the arm; DESIGN.md vehicle budget is 10,000

reset()
bpy.ops.import_scene.gltf(filepath=SRC)
rover = bpy.context.scene.objects["MSL"]

# tex_05 (512 px): medallions centred at x 463, y 90 / 193 / 290 / 393 from the top, radius about 45.
# Fill each with the grey of the calibration-target bezel beside them, so the part reads as a blank plate.
img = bpy.data.images["tex_05.jpg"]
w, h = img.size
px = np.empty(w * h * 4, dtype=np.float32)
img.pixels.foreach_get(px)
px = px.reshape(h, w, 4)                       # Blender rows start at the bottom
grey = np.median(px[h - 300:h - 100, 262:280].reshape(-1, 4), axis=0)
yy, xx = np.mgrid[0:h, 0:w]
for cy in (90, 193, 290, 393):
    px[((xx - 463) ** 2 + (yy - (h - 1 - cy)) ** 2) <= 50 ** 2] = grey
img.pixels.foreach_set(px.ravel())
img.pack()

# Face +Y (the arm and mast lead), and scale by the body length: front wheels' leading edge to the rear RTG
rover.rotation_mode = "XYZ"
rover.rotation_euler = (0, 0, math.pi)
bpy.context.view_layer.objects.active = rover
rover.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
me = rover.data
wheel_ix = [i for i, m in enumerate(me.materials) if m.name == "wheels"][0]
wheel_y = [me.vertices[v].co.y for p in me.polygons if p.material_index == wheel_ix for v in p.vertices]
rear = min(v.co.y for v in me.vertices)
body = max(wheel_y) - rear
print("CURIOSITY body length before scaling", round(body, 3), "m; overall", round(rover.dimensions.y, 3))
rover.scale = (LENGTH / body,) * 3
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

d = rover.modifiers.new("Decimate", "DECIMATE")
d.ratio = TRIS / sum(len(p.vertices) - 2 for p in me.polygons)
bpy.ops.object.modifier_apply(modifier=d.name)
rover.name = "curiosity-convcol"  # a hull: nobody walks inside a rover
ground_origin()
print("FORGE_DONE", export_glb("vehicle_curiosity"), *render_previews("vehicle_curiosity"))

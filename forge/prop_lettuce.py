# Lettuce in four growth stages, prop_lettuce_1..4, from the Quaternius crops pack (CC0, converted to GLB
# in assets-cache). Only the material changes: the pack's "DarkGreen" becomes a DESIGN.md role. Kept at the
# pack's size (stage 4 is 1 m wide, a real head is far smaller): the game scales them from a reality row.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), *[".."] * 4, "assets-cache", "quaternius", "crops", "glb")
ROLE = "plant"

for n in range(1, 5):
    reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, f"Lettuce_{n}.glb"))
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH":
            o.matrix_world = o.matrix_world.copy()
            o.parent = None
            o.name = f"lettuce_{n}"
            o.data.materials.clear()
            o.data.materials.append(mat(ROLE))
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    done(f"prop_lettuce_{n}")

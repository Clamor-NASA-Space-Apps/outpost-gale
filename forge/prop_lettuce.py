# Lettuce in four growth stages, prop_lettuce_1..4, from the Quaternius crops pack (CC0, converted to GLB
# in assets-cache). Only the material changes: the pack's "DarkGreen" becomes a DESIGN.md role. Kept at the
# pack's size (stage 4 is 1 m wide, a real head is far smaller): the game scales them from a reality row.
# The pack's leaves are open single sheets, half of them facing down: with the engine culling back faces, a head
# seen from above was mostly holes onto the dark medium. Each leaf gets a back sheet with its normals reversed.
# The node is named `interior` (DESIGN.md weathering.clean): lettuce only grows indoors, and a clean mesh merges
# with the room's swept fit-out onto the room-light layer (world.gd ROOMS). Named after the pack, it merged with
# the outside and the greenhouse's grow light never reached it: lit by shade alone, it read almost black.
import os
import sys

import bmesh

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
            o.name = "interior"
            o.data.materials.clear()
            o.data.materials.append(mat(ROLE))
            # the pack's own custom normals would be copied to the back sheet unturned (lit from behind): drop them, so
            # each face's smooth flag shades it, the back sheet's normals reversed with its faces
            bpy.context.view_layer.objects.active = o
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
            bm = bmesh.new()
            bm.from_mesh(o.data)
            back = bmesh.ops.duplicate(bm, geom=bm.faces[:])["geom"]
            bmesh.ops.reverse_faces(bm, faces=[f for f in back if isinstance(f, bmesh.types.BMFace)], flip_multires=False)
            bm.to_mesh(o.data)
            bm.free()
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    done(f"prop_lettuce_{n}", solid=False)  # a plant in a bed blocks nobody

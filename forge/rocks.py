# Gale rocks from CC0 Poly Haven scans (3,000-triangle copies in assets-cache/rocks/): the scanned shape,
# re-sized, decimated to the rock budget, and dressed in DESIGN.md roles so they match the ground: grey
# `rock` on the sides, red `dust` settled on faces that look up. The scans' own photos are not kept; the
# `rock` role's layered texture is laid on in the engine.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/rocks.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

from shapes import finish, join, mat, reset, smooth  # noqa: E402

CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "assets-cache", "rocks")
# name: (scan, longest side in metres, height squash, triangles). Slabs are flat layered blocks, as at Gale.
ROCKS = {
    "rock_small_a": ("moon_rock_02", 0.25, 1.0, 500),
    "rock_small_b": ("moon_rock_04", 0.4, 1.0, 600),
    "rock_boulder_a": ("rock_07", 1.8, 1.0, 1800),
    "rock_boulder_b": ("moon_rock_02", 1.0, 0.85, 1500),
    "rock_slab_a": ("namaqualand_boulder_05", 2.0, 0.8, 1800),
    "rock_slab_b": ("moon_rock_01", 1.2, 0.7, 1200),
}
UP = 0.7  # a face (and its neighbours) this close to straight up holds dust

for name, (scan, size, squash, tris) in ROCKS.items():
    reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(CACHE, scan, f"{scan}_3k_tris.glb"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    rock = join(f"{name}-convcol", meshes) if len(meshes) > 1 else meshes[0]
    rock.name = f"{name}-convcol"
    mw = rock.matrix_world.copy()
    rock.parent = None
    rock.matrix_world = mw
    for o in [o for o in bpy.context.scene.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o)
    bpy.context.view_layer.objects.active = rock
    rock.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    s = size / max(rock.dimensions)
    rock.scale = (s, s, s * squash)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    d = rock.modifiers.new("Decimate", "DECIMATE")
    d.ratio = min(1.0, tris / len(rock.data.polygons))
    bpy.ops.object.modifier_apply(modifier=d.name)
    me = rock.data
    me.materials.clear()
    me.materials.append(mat("rock"))
    me.materials.append(mat("dust"))
    # how much each face looks up, blurred over its neighbours twice so dust lies in patches, not speckles
    up = [p.normal.z for p in me.polygons]
    near = [[] for _ in me.polygons]
    by_edge = {}
    for p in me.polygons:
        for k in p.edge_keys:
            by_edge.setdefault(k, []).append(p.index)
    for faces in by_edge.values():
        for a in faces:
            near[a] += [b for b in faces if b != a]
    for _ in range(2):
        up = [(up[i] + sum(up[j] for j in near[i])) / (1 + len(near[i])) for i in range(len(up))]
    for p in me.polygons:
        p.material_index = 1 if up[p.index] > UP else 0
    smooth(rock, 60)
    rock.select_set(False)
    finish(name)

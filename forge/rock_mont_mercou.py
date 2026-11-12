# Mont Mercou, the layered outcrop Curiosity climbed beside at Gale in 2021: LPG-3D's model (Gwenael Caravaca, LPG
# Nantes) built from NASA/JPL-Caltech/MSSS Navcam and Mastcam images, Sketchfab, CC BY-NC 4.0 (ASSETS.md). It
# stands for the lake rock the science goal is about: layers laid down in water. The model's ground is levelled
# (a plane fitted to its edge), the flat ground round the butte cut away (ours is under it), the rest decimated to
# the rock budget and its photo colour baked onto the low mesh at 2048 px (material `mercou_photo`, a DESIGN.md
# kit `keep`): decimating a photo model 500 times smears its texture atlas, baking does not.
# Kept at the model's own scale, read as metres (not checked against a NASA size). Collision is a hull (below).
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/rock_mont_mercou.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
from base_kit import *  # noqa: E402,F403
from mathutils import Matrix, Vector  # noqa: E402

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), *[".."] * 4, "assets-cache", "sketchfab", "mont_mercou_on_mars_-_3d_printable_model")
TRIS, CUT, BAKE = 1600, 0.8, 2048  # triangles, metres over the fitted ground kept, baked texture size
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
high = join("high", ms)
bpy.ops.object.select_all(action="DESELECT")
high.select_set(True)
bpy.context.view_layer.objects.active = high
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# level it: a plane through the mesh's open edge (the cut-off ground all round) by least squares, z = a x + b y + c
bm = bmesh.new()
bm.from_mesh(high.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.005)  # the importer splits vertices at UV seams; UVs stay per corner
edge = [v.co.copy() for v in bm.verts if v.is_boundary]
n = len(edge)
sx, sy, sz = (sum(p[i] for p in edge) for i in range(3))
sxx, syy, sxy = sum(p.x * p.x for p in edge), sum(p.y * p.y for p in edge), sum(p.x * p.y for p in edge)
sxz, syz = sum(p.x * p.z for p in edge), sum(p.y * p.z for p in edge)
A = Matrix(((sxx, sxy, sx), (sxy, syy, sy), (sx, sy, n)))
a, b, c = A.inverted() @ Vector((sxz, syz, sz))
up = Vector((-a, -b, 1)).normalized()
turn = up.rotation_difference(Vector((0, 0, 1))).to_matrix().to_4x4()
bm.transform(turn @ Matrix.Translation((0, 0, -c)))
bm.to_mesh(high.data)
bm.free()

# the low mesh: the butte only, decimated
low = high.copy()
low.data = high.data.copy()
low.name = "mercou"
bpy.context.scene.collection.objects.link(low)
bm = bmesh.new()
bm.from_mesh(low.data)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if all(v.co.z < CUT for v in f.verts)], context="FACES")
islands, seen = [], set()  # what is left in pieces: keep the biggest (the butte), drop the crumbs along the cut
for f in bm.faces:
    if f.index in seen:
        continue
    todo, isle = [f], []
    seen.add(f.index)
    while todo:
        g = todo.pop()
        isle.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen:
                    seen.add(h.index)
                    todo.append(h)
    islands.append(isle)
islands.sort(key=len)
bmesh.ops.delete(bm, geom=[f for isle in islands[:-1] for f in isle], context="FACES")
bm.to_mesh(low.data)
bm.free()
d = low.modifiers.new("Decimate", "DECIMATE")
d.ratio = TRIS / len(low.data.polygons)
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.object.modifier_apply(modifier=d.name)
while len(low.data.uv_layers):
    low.data.uv_layers.remove(low.data.uv_layers[0])
low.data.uv_layers.new(name="UVMap")
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(island_margin=0.01)
bpy.ops.object.mode_set(mode="OBJECT")

# bake the photo colour from the high mesh onto the low one
img = bpy.data.images.new("mercou_photo", BAKE, BAKE)
m = bpy.data.materials.new("mercou_photo")
m.use_nodes = True
tex = m.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = img
m.node_tree.links.new(tex.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
m.node_tree.nodes.active = tex
low.data.materials.clear()
low.data.materials.append(m)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = 1
# the photo as emission on the high mesh, baked as EMIT: no lighting term that could come out black
src = high.data.materials[0].node_tree
photo = next(n for n in src.nodes if n.type == "TEX_IMAGE")
glow = src.nodes.new("ShaderNodeEmission")
src.links.new(photo.outputs["Color"], glow.inputs["Color"])
src.links.new(glow.outputs["Emission"], next(n for n in src.nodes if n.type == "OUTPUT_MATERIAL").inputs["Surface"])
sc.render.bake.use_selected_to_active = True
sc.render.bake.cage_extrusion = 0.4
sc.render.bake.max_ray_distance = 1.0
sc.render.bake.margin = 4
bpy.ops.object.select_all(action="DESELECT")
high.select_set(True)
low.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.object.bake(type="EMIT")
path = os.path.join(SRC, "mercou_baked.jpg")  # beside the download, not in the project
img.filepath_raw, img.file_format = path, "JPEG"
img.save()
tex.image = bpy.data.images.load(path)
bpy.data.objects.remove(high)
smooth(low, 60)

# collision only: the hull of the low mesh with its open edge carried 0.6 m straight down. The cut edge is a thin
# wedge on the ground; as a hull's slope it let the hero step up into the solid (sweep_test), as a wall it cannot
hull = low.copy()
hull.data = low.data.copy()
hull.name = "mercou-convcolonly"
bpy.context.scene.collection.objects.link(hull)
bm = bmesh.new()
bm.from_mesh(hull.data)
rim = [e for e in bm.edges if e.is_boundary]
new = bmesh.ops.extrude_edge_only(bm, edges=rim)["geom"]
bmesh.ops.translate(bm, verts=[v for v in new if isinstance(v, bmesh.types.BMVert)], vec=(0, 0, -0.6))
keep = bmesh.ops.convex_hull(bm, input=bm.verts)  # the engine hulls it anyway; stored as a hull it costs few triangles
bmesh.ops.delete(bm, geom=list(set(bm.verts) - set(v for v in keep["geom"] if isinstance(v, bmesh.types.BMVert))), context="VERTS")
bm.to_mesh(hull.data)
bm.free()
done("rock_mont_mercou", solid=False)  # the drawn butte carries no body of its own: the hull blocks

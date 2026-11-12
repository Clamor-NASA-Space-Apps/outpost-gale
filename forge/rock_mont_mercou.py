# Mont Mercou, the layered outcrop Curiosity climbed beside at Gale in 2021: LPG-3D's model (Gwenael Caravaca, LPG
# Nantes) built from NASA/JPL-Caltech/MSSS Navcam and Mastcam images, Sketchfab, CC BY-NC 4.0 (ASSETS.md). It
# stands for the lake rock the science goal is about: layers laid down in water. The model's ground is levelled
# (a plane fitted to its edge), the flat ground round the butte cut away (ours is under it), the rest decimated to
# the rock budget and its photo colour baked onto the low mesh at 2048 px (material `mercou_photo`, a DESIGN.md
# kit `keep`): decimating a photo model 500 times smears its texture atlas, baking does not.
# Kept at the model's own scale, read as metres (not checked against a NASA size). Bedded like a real outcrop: its
# open edge (where the cut left it, 0.4 to 0.9 m over the fitted ground) is carried down SKIRT m as a skirt that flares
# a little, as a talus apron does, and the rock is bedded with its ground line at the edge's BURY share of heights, so
# drift sand covers its foot and the skirt: a stretched skirt above the sand read as a striped band (13 Nov captures).
# `ground_level` (an empty, child of the mesh) marks that line, and the world rests the rock on it (world.gd rest()).
# Near the line the baked photo fades to the dust role's colour, drift sand banked against the foot. Collision is
# the drawn mesh itself (`-col`): closed down into the ground, it has no thin edge to step onto.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/rock_mont_mercou.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
from base_kit import *  # noqa: E402,F403
from mathutils import Matrix, Vector  # noqa: E402

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), *[".."] * 4, "assets-cache", "sketchfab", "mont_mercou_on_mars_-_3d_printable_model")
TRIS, CUT, BAKE = 1400, 0.8, 2048  # triangles, metres over the fitted ground kept, baked texture size
SKIRT, FLARE, DRIFT, BURY = 1.5, 0.4, 0.6, 0.9  # m under the fitted ground, m outward at its foot, m of sand banked
# at the base, the share of the open edge under the sand
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
bm = bmesh.new()
bm.from_mesh(low.data)
rim_z = sorted(v.co.z for v in bm.verts if v.is_boundary)
bm.free()
GROUND = rim_z[int(BURY * (len(rim_z) - 1))]  # the ground line: this share of the open edge is under it
print("mercou open edge %.2f to %.2f m, ground line %.2f m" % (rim_z[0], rim_z[-1], GROUND))
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
# drift sand at the foot: the photo fades to the dust role's colour over the lowest DRIFT m, in patches
pos = src.nodes.new("ShaderNodeSeparateXYZ")
src.links.new(src.nodes.new("ShaderNodeNewGeometry").outputs["Position"], pos.inputs[0])
grain = src.nodes.new("ShaderNodeTexNoise")
grain.inputs["Scale"].default_value = 0.6
up = src.nodes.new("ShaderNodeMath")
up.operation = "MULTIPLY_ADD"  # height plus a patchy share of DRIFT, so the line wanders
src.links.new(grain.outputs["Fac"], up.inputs[0])
up.inputs[1].default_value = DRIFT * 0.6
src.links.new(pos.outputs["Z"], up.inputs[2])  # From Min and Max below are over the ground line
fade = src.nodes.new("ShaderNodeMapRange")
fade.inputs["From Min"].default_value = GROUND + DRIFT * 0.3
fade.inputs["From Max"].default_value = GROUND + DRIFT * 1.3
fade.inputs["To Min"].default_value = 1.0
fade.inputs["To Max"].default_value = 0.0
src.links.new(up.outputs[0], fade.inputs["Value"])
sand = src.nodes.new("ShaderNodeMix")
sand.data_type = "RGBA"
src.links.new(fade.outputs["Result"], sand.inputs["Factor"])
src.links.new(photo.outputs["Color"], sand.inputs["A"])
sand.inputs["B"].default_value = mat("dust").node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value
src.links.new(sand.outputs["Result"], glow.inputs["Color"])
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
# the skirt, after the bake (no photo under the cut to bake from): the open edge carried straight down under the
# ground and a little outward, each new corner taking the colour of the rim corner above it (sand near the foot)
bm = bmesh.new()
bm.from_mesh(low.data)
uv = bm.loops.layers.uv.active
mid = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
rim = [e for e in bm.edges if e.is_boundary]
made = bmesh.ops.extrude_edge_only(bm, edges=rim)["geom"]
drop = {v for v in made if isinstance(v, bmesh.types.BMVert)}
for v in drop:
    out = Vector((v.co.x - mid.x, v.co.y - mid.y, 0)).normalized()
    v.co = Vector((v.co.x, v.co.y, -SKIRT)) + out * FLARE
for f in {f for v in drop for f in v.link_faces}:
    for lp in f.loops:
        if lp.vert in drop:
            top = next(e.other_vert(lp.vert) for e in lp.vert.link_edges if e.other_vert(lp.vert) not in drop)
            lp[uv].uv = next(q[uv].uv for q in f.loops if q.vert == top)
bm.to_mesh(low.data)
bm.free()
smooth(low, 60)

low.name = "mercou-col"  # its own triangles block (world-collision rule 1)
mark = bpy.data.objects.new("ground_level", None)  # the fitted ground, where the world rests the rock
bpy.context.scene.collection.objects.link(mark)
mark.parent = low
mark.location.z = GROUND
done("rock_mont_mercou", solid=False)

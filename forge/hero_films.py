# Side-view films of the hero's clips: 8 frames per clip in one strip, camera at the side looking a little down, the hero carried forward at the clip's ground speed over a floor ruled every 0.25 m, so a planted
# boot stays on one mark and a sliding one does not. The hop strip flies the body on a Mars-gravity arc.
#   blender -b --python-exit-code 1 -P forge/hero_films.py -- models/character_suited.glb data/clips.json <out dir>
import json
import os
import subprocess
import sys

import bpy

glb, clips_json, out = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:]]
os.makedirs(out, exist_ok=True)
clips = json.load(open(clips_json))["clips"]
G, AIR = 3.73, clips["hop_air"]["length"]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
sc = bpy.context.scene
sc.render.fps = 30
arm = next(o for o in sc.objects if o.type == "ARMATURE")
root = arm.parent or arm
sc.render.engine = "BLENDER_WORKBENCH"
sc.render.resolution_x, sc.render.resolution_y = 300, 420
sh = sc.display.shading
sh.light, sh.color_type, sh.show_cavity, sh.show_shadows = "STUDIO", "MATERIAL", True, True
floor_m = bpy.data.materials.new("floor")
floor_m.diffuse_color = (0.55, 0.38, 0.28, 1)
mark_m = bpy.data.materials.new("mark")
mark_m.diffuse_color = (0.1, 0.1, 0.1, 1)
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, -15, -0.001))
bpy.context.object.scale = (3, 40, 1)
bpy.context.object.data.materials.append(floor_m)
for k in range(-160, 20):  # a rule every 0.25 m, a long one every metre
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.6, k * 0.25, 0.002))
    bpy.context.object.scale = (0.5 if k % 4 else 1.4, 0.012, 0.004)
    bpy.context.object.data.materials.append(mark_m)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type, cam.data.ortho_scale = "ORTHO", 2.4
sc.collection.objects.link(cam)
sc.camera = cam


def play(name, t):
    act = bpy.data.actions[name]
    arm.animation_data_create()
    arm.animation_data.action = act
    arm.animation_data.action_slot = act.slots[0]
    sc.frame_set(int(t * 30), subframe=(t * 30) % 1)


def shot(path, y, z=0.0):
    root.location = (0, y, z)
    cam.location = (4.0, y, 1.6)  # tipped 10 degrees down so the floor rules show
    cam.rotation_euler = (1.3963, 0, 1.5708)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def strip(name, frames):
    """frames: [(clip, t, y, z)] -> one PNG of len(frames) panels."""
    paths = []
    for k, (clip, t, y, z) in enumerate(frames):
        play(clip, t)
        p = os.path.join(out, f"_{name}_{k}.png")
        shot(p, y, z)
        paths.append(p)
    dst = os.path.join(out, f"{name}.png")
    inputs = sum((["-i", p] for p in paths), [])
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *inputs, "-filter_complex", f"hstack=inputs={len(paths)}", dst], check=True)
    for p in paths:
        os.remove(p)
    print("FILM", dst)


for name, c in clips.items():
    if name.startswith("hop_"):
        continue
    L, v = c["length"], c.get("speed", 0.0)
    strip(name, [(name, L * k / 8, -v * L * k / 8, 0.0) for k in range(8)])
# the hop: start (crouch, take-off), the flight on the arc, the landing
s, l = clips["hop_start"]["length"], clips["hop_land"]["length"]
v0 = G * AIR / 2
hop = [("hop_start", 0.0, 0, 0), ("hop_start", s * 0.55, 0, 0), ("hop_start", s * 0.98, 0, 0)]
hop += [("hop_air", AIR * u, 0, v0 * AIR * u - G * (AIR * u) ** 2 / 2) for u in (0.25, 0.5, 0.85)]
hop += [("hop_land", l * 0.25, 0, 0), ("hop_land", l * 0.6, 0, 0)]
strip("hop", hop)

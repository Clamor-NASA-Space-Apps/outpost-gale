# Frame drops and stutter since 13 Nov: shaders compiling in play (14 Nov 2026)

## TL;DR
The build from 13 Nov morning (def936b) and today's (e21b136) cost the same per frame: about 9 ms of GPU work and
about 225 draw calls on the Iris Xe at the laptop preset. What changed is **shader variants compiling in play**: 14
hitches of 60 to 550 ms in a 90 s run on a cold cache, against 3 on 13 Nov. A fresh Windows or Mac install (or any
machine the first time) gets every one of them. All of them come from three things that landed on 13 and 14 Nov:

1. **The helmet spot (d939df6).** `player/suit_lamps.gd` keeps a SpotLight3D on at a glimmer, day and night, reaching
   12 m. Compatibility compiles a separate variant of each material for every set of lights that reaches it: no
   light, a lamp, a spot, or both (`DISABLE_LIGHT_OMNI` and `DISABLE_LIGHT_SPOT` in `scene.glsl`). Before the spot
   there were two sets. Now there are four, and the beam moves with the hero.
2. **`HouseStyle.warm()` covered only two of the four sets.** Its lamp group also got the spot (e85a454 in the
   factory), so "lamp, no spot" was no longer warmed. And the scene's own lights reached the warm stage: the base
   lamps glimmer with a 14 m reach and stand 2 to 9 m from it, and the hero's spot reached it too. So every group
   was lit, and "no light" and "spot only" never compiled behind the cover. Particle and MultiMesh copies missed
   their groups' lights as well: a new MultiMesh instance is all zeros, and an emitter's box spans several groups.
3. **The Sol 1 opening (d939df6) starts with the hero hidden** inside HAB 1, with the lens close. While the hero is
   hidden no mesh wears the solid hero shader, so nothing warmed it, and its first sight at the hatch was a 0.5 s
   compile. Separately, meshes inside two probes (a room's and the base's) compiled a variant in play the first
   time the beam was off them (4 compiles, 0.55 s).

The warm-up's other change, hiding the scene during the warm-up (2e42da6), is **not** a cause: putting it back
changed nothing (run `exp-nohide`, 16 hitches).

## How it was measured
- `tests/perf_walk.gd` runs the same script on any commit: boot through `ui/boot.tscn` as a player does, then 25 s
  of the game alone (the Sol 1 opening), then stand, walk, walk while turning, sprint while turning, look round,
  back up, and two sky skips to dusk and night while walking. One CSV row per frame, plus the current beat, the
  room, the helmet lamps and the hero's fade.
- Cold: `MESA_SHADER_CACHE_DISABLE=true`, and `user://shader_cache` moved away before each run (the original is
  kept in the scratchpad and was put back after).
- **Which compile is which:** Godot writes every variant it compiles to `user://shader_cache/SceneShaderGLES3/<base>/<version>.cache`
  at once (`shader_gles3.h` `_version_bind_shader`). Its format is variant count, then for each variant a
  specialization key and the program binary. `perf_walk.gd` copies the cache as the cover lifts.
  `tools/shader_cache_list.py` lists (version, mode, key) from both copies, and the diff is exactly what compiled
  in play. The file times tell which hitch each one was. The key bits are `scene.glsl` `#[specializations]` in
  order: bit 2 `DISABLE_LIGHT_OMNI`, bit 3 `DISABLE_LIGHT_SPOT`, bit 5 `DISABLE_REFLECTION_PROBE`, bit 27
  `SECOND_REFLECTION_PROBE`.
- A one-box test project (no game) confirmed the four light variants, and that `light_cull_mask = 0` takes a light
  off a mesh's variant.

## Numbers (Iris Xe, 1920x1080 full screen, laptop preset, frame times in ms)

### Cold cache, real screen (vsync on: Wayland always syncs)
| Build | In-play frames over 33 ms | Worst | p99 | Opening | Walking | Sky skips |
|---|---|---|---|---|---|---|
| 13 Nov, def936b (no opening) | 3 | 393 | 18.3 | n/a | 2 | 1 |
| 14 Nov, e21b136 | 14 | 535 | 20.9 | 7 | 4 | 3 |
| e21b136, spot hidden (diagnosis only) | 8 | 471 | 20.5 | 6 | 0 | 2 |
| e21b136 + fix | **0** | **33** | 21.5 | 0 | 0 | 0 |

Warm cache, vsync on, both builds: median 16.67, no frame over 33 ms in play except a few compiles, GPU 8.8 to 9.0.

### Per-frame cost (X11 so vsync is really off, warm cache, the same boot run, all phases after the cover)
| Build | Frame p50 / p99 | GPU p50 / p99 | Script (process) p50 / p99 | Physics p50 / p99 | Draw calls |
|---|---|---|---|---|---|
| 13 Nov, def936b | 13.4 / 20.1 | 12.8 / 18.6 | 0.78 / 1.55 | 1.03 / 2.85 | 250 |
| 14 Nov, e21b136 | 14.0 / 24.2 | 13.4 / 22.4 | 0.79 / 1.71 | 1.33 / 5.06 | 225 |
| e21b136 + fix | 13.5 / 21.9 | 13.1 / 20.6 | 0.71 / 1.51 | 1.20 / 4.33 | 230 |

The frame is GPU-bound, and all three cost about the same. With vsync off the GPU time reads higher than in the
vsync runs (8.9 ms); why was not measured. The one CPU cost that grew is physics: its slow frames went from 2.9 to
5 ms at p99. Which script causes that was not traced. It is small beside a 16.7 ms frame.

## The fix (on top of e21b136)
- `addons/forge/house_style.gd` `warm()`:
  - one group of copies for each set of lights the scene can put on a mesh: none, a lamp, a spot (only if the
    scene has a SpotLight3D), and both;
  - the scene's own lamps and spots get `light_cull_mask = 0` while the copies compile. Not `visible`: the sky
    clock and the lamp pool show their lamps again every frame;
  - MultiMesh copies get a real transform, and particle copies a small `visibility_aabb`, so only their own
    group's lights pair with them;
  - extra materials (the hero's) cast shadows and get a copy outside the probes;
  - after the copies, the scene itself is drawn three times: once with its spots off, once with its lamps off,
    then as it is. That catches the meshes inside two probes.
- `sandbox/sandbox.gd` `_warm()` also warms the solid hero shader, which no mesh wears while the hero is hidden.
- What it costs: the warm-up draws about twice as many copies (688 on this scene) behind the cover, 6 a frame. The
  launch until the cover lifts takes 22.4 s before and 38.5 s after on a cold cache (Mesa's cache off), and 7.7 s
  before and 8.9 s after on a warm one. A native build pays the cold cost once, because Godot keeps its shader
  cache. **The web build keeps no cache, so it pays more on every visit**: not measured here. The look is
  unchanged: no DESIGN.md value, preset, light or material changed.

## Not the cause (checked)
- The default preset: both commits start a desktop on `laptop` (`HouseStyle.default_quality()`, the same quality
  list). Since fb02a6f every launch starts there, because settings.cfg is deleted. "max" only comes from the
  Settings menu or the debug key G, which steps to the next preset in every build.
- Draw calls: about 225 in play on both builds. GPU time: 8.8 to 9.0 ms on both.
- The warm-up hiding the scene (2e42da6), and no 3D on the boot frame (e21b136): load only.

## Still open
- The factory copy of `house_style.gd` (`tooling/godot/addons/forge/`) needs the same `warm()` change, then
  `new-project.mjs --sync`.
- A 75 to 98 ms script frame as the cover lifts (process, not render): the first frame of the opening's beats.
- The web build has no shader cache at all, so it pays the bigger warm-up on every visit, behind the cover.
- The Mac at 30 to 40 fps (and 21 fps on max under ANGLE) is per-frame cost, not compiles. Not measured here (no
  Mac).

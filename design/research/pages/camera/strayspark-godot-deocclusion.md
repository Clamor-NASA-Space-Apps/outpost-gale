# StraySpark Godot Camera System: Third person and deocclusion (third-party Godot add-on docs)
https://www.strayspark.studio/docs/godot-camera-system/third-person-and-deocclusion
Fetched 14 Nov 2026 (WebFetch, quoted passages)

- PULL_FORWARD: "slides along the camera → target ray to just in front of the obstacle nearest the target."
- Deoccluder: "the camera eases back over `damping`; `damping_when_occluded` controls how fast it moves out of the way." (page defaults: damping 0.5, damping_when_occluded 0 s)
- Rig: "the boom shortens within `collision_in_time` (keep it near 0 so the camera never sees inside a wall)." Boom "grows back over `collision_out_time`." (page defaults 0 s and 0.5 s)
- "Following John Nesky's _50 Game Camera Mistakes_, the rig never yaws on its own to dodge walls"
- "The rig writes `state.extra["avatar_fade"]` (0..1) when the boom gets shorter than `avatar_fade_distance`." (page defaults 1 m and 0.4 m full fade)

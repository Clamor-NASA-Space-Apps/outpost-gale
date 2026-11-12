# godotengine/godot issue 90175 "Jumping Shadows" (fetched 2026-11-12 via the GitHub API)
URL: https://github.com/godotengine/godot/issues/90175

## Issue (2024-04-03T16:33:25Z)
### Tested versions

At first I thought it was due to a problem with the voxel engine I'm using, in which the effect is amplified for some reason. But after some tests without the voxel module I realized that the problem also occurs in the latest official version of Godot and in the latest commit of the master branch.

### System information

Windows 11 - NVIDIA GeForce RTX 4070 Laptop - Godot v4.2.1.stable - Vulkan (Forward+)

### Issue description

While I was trying to create a day and night cycle for my game I have discovered that when rotating a DirectionalLight3D slowly in the X axis the shadows start to make a very strange effect as if they were jumping.

https://github.com/godotengine/godot/assets/57621742/7ad15c65-f49b-4dcf-8863-99c3f8b1cff6

https://github.com/godotengine/godot/assets/57621742/9dce7a20-df95-4f14-b121-c2c93e6c2af2

### Steps to reproduce

1. Create a 3d scene.
2. Add some random objects.
3. Add a camera.
4. Add a DirectionalLight3D with the following script:

```gdscript
class_name Sun extends DirectionalLight3D

@export var speed: float = 0.01

func _process(delta) -> void:
	rotate_x(speed * delta)
```

### Minimal reproduction project (MRP)

[mrp.zip](https://github.com/godotengine/godot/files/14855450/mrp.zip)

## Calinou 2024-04-03T16:39:42Z
This is shadow map aliasing, which is expected. You're hitting a worst-case scenario because your voxels are perfectly aligned with the shadow map texture.

You can alleviate this by rotating your DirectionalLight on the *local* Z axis (which makes it look like you're "rolling" the light). This will not affect the angle at which shadows at casted, but it'll affect how pixelation occurs on the shadow. You'll probably want to rotate it by 45 degrees in this case so that you get a perfect 22.5 degree-degree angle in the shadow map texture, but try various rotations to see which one you like the most.

Here's the light rotated by 22.5 degrees on local Z in the MRP: [test-rotated.zip](https://github.com/godotengine/godot/files/14855711/test-rotated.zip)
Notice how aliasing is pretty much completely gone when you run the project. You'll get some shimmering instead, which can't be fully prevented but can be alleviated by increasing shadow filter quality and/or enabling TAA.

https://github.com/godotengine/godot/assets/180032/9c2c6fd2-b9f7-4cbe-80d6-22643c4032a7

When TAA is enabled, you can also add this line at the end of `_process()` in your script attached to the DirectionalLight3D node:

```gdscript
rotate_object_local(Vector3.FORWARD, randf_range(-PI, PI))
```

This results in a very smooth appearance with almost no visible aliasing:

https://github.com/godotengine/godot/assets/180032/4c69ef6d-0160-46ff-b903-acdec1e55b11

This trick also works with OmniLight3D and SpotLight3D, by the way. See [this proposal](https://github.com/godotengine/godot-proposals/issues/4632) for details.

You can also increase directional shadow filter quality in the Project Settings (at a performance cost).

## ddel-rio 2024-04-04T11:25:58Z
Thank you for the quick and detailed response!
Although not perfect, I have managed to reach an acceptable result by following your advice.

However, I would like to point out that I can't help but feel that Godot is currently immature compared to other engines where shadows work perfectly without the need for tricks.
So I hope this aspect will be polished in the future.

## Calinou 2024-04-04T14:30:41Z
> However, I would like to point out that I can't help but feel that Godot is currently immature compared to other engines where shadows work perfectly without the need for tricks.
So I hope this aspect will be polished in the future.

This is one reason why many AAA games don't rotate the sunlight continuously, but rotate it by small steps every few seconds instead (with some interpolation occurring between each step). This also improves performance significantly by not having to update the DirectionalLight3D shadow map every frame. This periodic snapping becomes obvious if you look at a timelapse recording, but it's hard to notice during actual gameplay.

This issue can't be *completely* resolved by any engine, unless you switch to raytraced shadows which naturally don't have undersampling or shadow acne/peter-panning issues. These also impose a heavy performance cost, especially when displayed on transparent objects.

If you've gotten a better result in another engine out of the box, it's likely because its directional shadow map is rotated differently by default. This will result in better shadows in some scenarios, but worse shadows in other scenarios as well. Shadow rendering is always a game of tradeoffs :slightly_smiling_face: 

## NuclearPhoenixx 2025-08-06T22:28:16Z
> This is one reason why many AAA games don't rotate the sunlight continuously, but rotate it by small steps every few seconds instead (with some interpolation occurring between each step). This also improves performance significantly by not having to update the DirectionalLight3D shadow map every frame.

Would interpolation not defeat the entire purpose of stepping the rotation in the first place?

## Calinou 2025-08-07T12:59:08Z
> Would interpolation not defeat the entire purpose of stepping the rotation in the first place?

If the interpolation only runs for a small period of time, not really. Performance-wise, it's not an ideal solution (as worst-case framerates are not improved by this, only average framerates), but many developers consider it to be better than rotating the light every frame. In terms of visuals, the flickering is less noticeable when interpolation runs on a small period of time, as it will move faster than if the light was being rotated every frame.

## NuclearPhoenixx 2025-08-07T13:09:35Z
Oh, I see. So essentially what you're suggesting is having the light rotate in smoothed bursts every now and then?

## Calinou 2025-08-07T13:10:55Z
> So essentially what you're suggesting is having the light rotate in smoothed bursts every now and then?

Yes 🙂 

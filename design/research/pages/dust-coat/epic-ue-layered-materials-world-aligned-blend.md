# Epic Games, "Creating Layered Materials in Unreal Engine" (official docs)
URL: https://dev.epicgames.com/documentation/unreal-engine/creating-layered-materials-in-unreal-engine
Fetched: 2026-11-12 (WebFetch; quotes as returned)

> The layered material "uses a world-aligned blend to automatically place snow on the upward facing surfaces of the mesh"
> "blend function always checks for the top surface, meaning even as you rotate the object, the snow Material remains on top"
> "The WorldAlignedBlend node controls the position and sharpness of the Material blend."
> "World_Aligned_Blend will power the Layer Blend based on the direction the surface is pointed"
> "Set the Blend Sharpness value to 10."
> BlendBias "allows you to adjust the vertical position on your mesh where the blend occurs."
(The page gives no performance cost or instruction count.)

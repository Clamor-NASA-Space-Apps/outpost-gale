# Geiss, "Generating Complex Procedural Terrains Using the GPU", GPU Gems 3, chapter 1, section 1.5 Texturing and Shading (NVIDIA)
URL: https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu
Fetched: 2026-11-12 (WebFetch; quotes as returned)

> triplanar texturing is "three different planar projections, one along each of the three primary axes (x, y, and z)"
> "At any given point, we use the projection that offers the least distortion (stretching) at that point."
> "a surface point whose normal vector pointed mostly in the +x or -x direction would use the yz planar projection."
> "A blending range of roughly 10 to 20 degrees tends to work well."
> "Triplanar texturing can be done in a single render pass."

Example 1-3, blend weights:
```
// Determine the blend weights for the 3 planar projections.
float3 blend_weights = abs( N_orig.xyz );
blend_weights = (blend_weights - 0.2) * 7;
blend_weights = max(blend_weights, 0);
blend_weights /= (blend_weights.x + blend_weights.y + blend_weights.z ).xxx; // Force weights to sum to 1.0 (very important!)
```
Cost: the listing samples three colour and three bump textures per pixel (6 fetches); the chapter states no fetch count itself.

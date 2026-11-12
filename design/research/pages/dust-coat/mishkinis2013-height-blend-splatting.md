# Andrey Mishkinis, "Advanced Terrain Texture Splatting", Game Developer (Gamasutra blog), July 16, 2013
URL: https://www.gamedeveloper.com/programming/advanced-terrain-texture-splatting
Fetched: 2026-11-12 (WebFetch; quotes as returned)

Linear blend:
> "Simplest way of blending is to multiply texture color with opacity and then sum results."
> `return texture1.rgb * a1 + texture2.rgb * a2;`
> "the transition is smooth but unnatural." "Stones look evenly soiled by sand, but in real world it doesn't happen."

Height blend (dust/sand fills cracks, tops stay clean):
> "Sand doesn't stick to stones, instead it falls down and fills cracks between them, leaving tops of stones pure."
> "in this example we consider depth map is generated from grayscaled image and stored in alpha channel of texture."
> `return texture1.a + a1 > texture2.a + a2 ? texture1.rgb : texture2.rgb;`
> "we will take several pixels in depth instead of one and blend them." `float depth = 0.2;`
> `return (texture1.rgb * b1 + texture2.rgb * b2) / (b1 + b2);`
Cost: one extra channel (alpha) per texture already sampled; no extra fetch.

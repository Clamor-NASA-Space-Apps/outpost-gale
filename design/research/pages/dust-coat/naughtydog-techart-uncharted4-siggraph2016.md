# Brinck, Jiang, Maximov, "The Technical Art of Uncharted 4", SIGGRAPH 2016 talk (Naughty Dog), speaker notes
URL: https://advances.realtimerendering.com/other/2016/naughty_dog/NaughtyDog_TechArt_Final.pdf
Fetched: 2026-11-12 (curl; PDF saved beside this file)

Coat on upward faces only:
> "And the artist used the Surface Transparency control to blend in some frost, applying it with a Fresnel falloff, only to the upward-facing surfaces." (ice sculpture, slide 79)

Dust as a "fuzzy" layer, not a shiny one:
> "Many surfaces in the world exhibit this "fuzzy" mossy behavior. From fabric to distant foliage, we see similar behavior. Even subtle phenomena like dust or peach fuzz have these same fuzzy characteristics."

A painted mask plus a parametric layer (their wetness system; the same shape as a dust coat):
> "And here's a visualization of the wetness mask the artists painted."
> "C) Region where water has saturated the surface, causing a darkening of the albedo, but not significantly affecting normals or specular response."
> "The artists have control of two parameters, "Wetness" and "Porosity" ... Porosity affects darkening of the base color ... Note that we just lerp to a "squared" version of the base color – compared to real-world reference, this is a reasonable approximation..."

Cost note (their wind/interaction system, for the "one buffer, constant cost" pattern):
> "That allowed us to have an unlimited amount of character and vehicle interactions for the constant cost of sampling this 2d buffer for every vertex. It was a good tradeoff."
> "...characters masking certain material layers from the objects underneath."
(No instruction count for material layers is given in the notes.)

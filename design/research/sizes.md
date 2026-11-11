# Real sizes, HUD readability, far backdrop and the terrain file 📏

Research for the asset lane (BRIEF §4, §6 questions 5 and 6). Checked 2026-11-12. Saved sources are under `pages/` (`sizes/`, `hud/`, `backdrop/`, `terrain/`); the scripts that produced the computed numbers are in `scripts/`.

Status: ✅ seen in the saved source (kwic hit) · ⚠️ reported, partial, or our own arithmetic from source data · ❌ not found, left out.

> [!TIP]
> **TL;DR.**
> - The habitat is a 5 m wide, 3.5 m tall drum.
> - The crewed rover is a 4.5 m long, 3 m tall van on 1 m wheels.
> - Curiosity is 3.0 × 2.8 × 2.1 m on 0.5 m wheels.
> - A suited astronaut is about 1 m wide, steps up 0.3 m with ease, and works best at hip height (1.1 m).
> - HUD text: at least 28 px at 1080p. Contrast at least 4.5:1. Touch targets about 2 cm for young kids.
> - Far backdrop: the north rim is 30 km away and 2.1 km above us. Mount Sharp's flanks fill the south-east sky up to 12°.
> - The "landing site" STL is the whole Gale region (about 340 × 250 km, 1.8 km grid), not a walkable patch.

---

## A. Real sizes 🏗️

| Thing | Value | Source URL | Status |
|---|---|---|---|
| Habitat Demonstration Unit (HDU PEM), shell | 5 m diameter, 3.5 m height, vertical cylinder with domed top and bottom (the PDF text reads "Sm diameter", an OCR slip for 5 m) | https://ntrs.nasa.gov/citations/20110011015 | ✅ |
| HDU, mass and hatches | "over 5 meters in diameter and nearly 12,000 kilograms"; four rectangular hatches at 90° around the wall, one round hatch in the top dome | https://ntrs.nasa.gov/citations/20110013501 | ✅ |
| HDU hatch size | not stated in either paper | | ❌ |
| Foundation Surface Habitat (Artemis) | crew of four, at least 28 days. No dimensions found | https://ntrs.nasa.gov/citations/20205008605 | ✅ crew / ❌ size |
| DRA 5.0 Mars surface habitat | no dimensions found in DRA 5.0 or its addendum | https://www.nasa.gov/wp-content/uploads/2015/09/373667main_nasa-sp-2009-566-add.pdf | ❌ |
| Hatch for a suited crew (lunar surface study) | recommended 60 × 40 in (1.52 × 1.02 m) hatch, 12 in (0.3 m) maximum step threshold, about 72 in (1.83 m) overhead clearance, corner radius 25 cm is fine | https://ntrs.nasa.gov/citations/20250004496 | ✅ |
| Handholds beside a hatch | 40 to 56 in (1.02 to 1.42 m) above the floor | same | ✅ |
| Suitport door size | the suitport drawing (NTRS 20130008729) has dimensions, but none can be read as an opening size without the figure | | ❌ |
| Crewed rover, Space Exploration Vehicle (surface concept) | length 14.7 ft (4.48 m), wheelbase 13 ft (3.96 m), height 10 ft (3.05 m) | https://www.nasa.gov/wp-content/uploads/2015/08/464826main_sev_factsheet_508.pdf | ✅ |
| SEV wheels | "4.7x39 inches in diameter, 12 inches wide": 39 in = 0.99 m diameter, 0.30 m wide. The "4.7x" is unexplained | same | ✅ / ⚠️ the 4.7 |
| SEV mass, crew, speed | weight 6,600 lb (2,994 kg), payload 2,200 lb (998 kg); crew of two, four in an emergency; "about 10 kilometers per hour" | same | ✅ |
| SEV turning | wheels "pivot 360 degrees, allowing it to drive in any direction" (crab steering). No turning radius given | same | ✅ / ❌ radius |
| SEV width | not stated | same | ❌ |
| SEV suitports and hatch | suitports allow "egress in less than 10 minutes"; a docking hatch joins it to a habitat or another rover; "Chariot Style Aft Driving Station". The suitports sit on the rear bulkhead in the drawing only; the text does not say where | same | ✅ / ⚠️ position |
| Lunar Electric Rover (SEV predecessor), inside | interior volume 10.8 m³, net habitable volume about 8.6 m³, crew of two, 14-day trial | https://ntrs.nasa.gov/citations/20100009798 | ✅ |
| Curiosity rover | length 3.0 m (not counting the arm), width 2.8 m, height to top of mast 2.1 m, arm 2.1 m | https://www.jpl.nasa.gov/news/press_kits/MSLLaunch.pdf | ✅ |
| Curiosity wheels and mass | wheel diameter 20 in (0.5 m), aluminium, twice Spirit's; rover 899 kg | same | ✅ |
| Curiosity high-gain antenna size | not stated in the press kits | | ❌ |
| Crewed Mars Ascent Vehicle cabin | about 1.58 m diameter for 2 crew, 1.8 m for 4, at least 2.2 m for 6. A 3 m cabin height appears in a worked example | https://ntrs.nasa.gov/citations/20150009500 | ✅ |
| DRA 5.0 ascent vehicle and lander | "notional two-stage Mars ascent vehicle of 40 t (wet mass)"; landers come down inside a 10 m × 30 m aeroshell. No standing height of the lander found | DRA 5.0 addendum (URL above) | ✅ / ❌ height |
| Starship (SpaceX, not NASA) | not confirmed: spacex.com renders with JavaScript and the NASA HLS pages saved here give no height. A search snippet said "roughly 50 meters" | | ❌ |
| DRA 5.0 Mars solar power module | each module 1.5 × 2.0 × 3.0 m, 5 kWe, two array wings totalling 290 m², "Each array wing is 2.5 m high × 58 m long", panels inclined 30°; five modules for 25 kWe | DRA 5.0 addendum | ✅ |
| NASA VSAT reference design (Moon south pole) | net deployed height 16 m (6 m array + 10 m clearance), array 6 m wide (two 3 m arrays), panels 3 m × 0.75 m, 8 panels per package, mast segments about 3 m, at least 10 kW. Vertical because the polar Sun is low; not a Gale layout | https://ntrs.nasa.gov/citations/20240004914 | ✅ |
| Relocatable 10 kW lunar array concept | "solar cell blankets freely hanging from a horizontal cross arm" on "a vertical slender telescoping mast" on a tripod base. No numbers in the abstract | https://ntrs.nasa.gov/citations/20205002773 | ✅ |
| Surface base comms dish | DRA 5.0 table 7-9: lunar capability "1-m diameter" high-gain antenna, "fixed antenna with 100° gimbals"; Mars capability "6-m diameter ... inflatable or deployable" | DRA 5.0 addendum | ✅ |
| Spacesuit backpack (PLSS) | "as much as 0.75 m x 0.56 m x 0.254 m" | https://ntrs.nasa.gov/citations/20150009500 | ✅ |
| Shuttle EMU backpack depth | "strict 18 ¾ inch front to back envelope" (0.48 m), set by the Orbiter hatch | https://ntrs.nasa.gov/citations/20260003024 (saved in the workspace at `research/junior-astronaut/pages/agent-habitat/`) | ✅ |
| Suited body width | 1 m horizontal corridor "derived from the breadth of the 99th percentile suited crew member without tools" | https://ntrs.nasa.gov/citations/20090032975 | ✅ |
| Crew height range (unsuited) | stature 148.6 to 194.6 cm (NASA example data, American female and male) | https://www.nasa.gov/wp-content/uploads/2015/03/human_integration_design_handbook_revision_1.pdf | ✅ |
| Suited height, helmet size | no NASA number found | | ❌ |
| Suited reach: best work zone | lunar EVA prime work area: "a cylinder 36 cm (14 in.) in diameter centered 1.1 m (43 in.) above the surface", for two-handed tasks; one-hand zones above and below | https://ntrs.nasa.gov/citations/20090032975 | ✅ |
| Suited reach: the ground | "it is difficult to reach objects on or near the surface"; Apollo crews "assumed awkward positions" | same | ✅ |
| Suited step-up | xEMU suit tests: front step 17.1 to 30.1 in (43.4 to 76.5 cm) to the boot marker, plus about 2 in (5 cm) of sole; 12 in (0.3 m) is "accessible to all crewmembers", especially with handholds | https://ntrs.nasa.gov/citations/20250004496 | ✅ |
| Cargo Transfer Bag (CTB) | single CTB about 50 cm long × 42 cm wide × 25 cm high; also half, double and triple sizes | https://ntrs.nasa.gov/citations/20160002631 | ✅ |
| CTBs as a storm shelter | multipurpose CTBs unfold into panels for "partitions, crew quarters, solar radiation storm shelters" | https://ntrs.nasa.gov/citations/20160004371 | ✅ |

**Kid version:** the rover is as long as a car and taller than a door. Its wheels come up to your waist. The habitat is a round room as wide as a classroom. You walk into it through a door that is 1.5 m tall.

---

## B. HUD readability for children 👀

Sources saved in `pages/hud/`. I re-ran kwic on the starred rows; the rest were checked by the research agent, with kwic lines.

| Rule | Value | Source URL | Status |
|---|---|---|---|
| Default font size (Game Accessibility Guidelines) * | "28px minimum when viewed on a 1080p screen", "a minimum rather than a target" (quoting Amazon's 10-foot UI) | https://gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size/ | ✅ |
| Font size (Xbox XAG 101) * | console 26 px at 1080p; PC 18 px at 1080p; mobile 18 px at 100 DPI, 36 at 200, 72 at 400 ("a 5.5" screen with a 1080p resolution is roughly 400 DPI"); text scalable to 200% | https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/101 | ✅ |
| Contrast (XAG 102) * | text and important elements at least 4.5:1; large text 3:1 (PC: 36 px at 1080p); high-contrast mode 7:1; measure against the lowest-contrast part of the background | https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/102 | ✅ |
| Contrast (GAG) | "at least 4.5:1" | https://gameaccessibilityguidelines.com/provide-high-contrast-between-text-ui-and-background/ | ✅ |
| WCAG 2.2 contrast | 1.4.3: 4.5:1, large text (18 pt or 14 pt bold, about 24 px or 18.5 px) 3:1; 1.4.6: 7:1; 1.4.11 non-text (icons, meter outlines): 3:1 | https://www.w3.org/TR/WCAG22/ | ✅ |
| WCAG 2.2 target size * | 2.5.8 (AA): 24 × 24 CSS px; 2.5.5 (AAA): 44 × 44 CSS px | same | ✅ |
| Apple HIG * | iOS control 44 × 44 pt default, 28 × 28 pt minimum; text 17 pt default, 11 pt minimum | https://developer.apple.com/design/human-interface-guidelines/accessibility | ✅ |
| Android * | touch target "at least 48dpx48dp. Larger is even better" | https://developer.android.com/guide/topics/ui/accessibility/apps | ✅ |
| Material 3 site | renders with JavaScript, not read | https://m3.material.io | ❌ |
| Kids' touch targets (Nielsen Norman Group) * | "at least 2cm × 2cm touch targets for young children", 4× the adult 1 cm. A 5 mm close button beat two 7-year-olds | https://www.nngroup.com/articles/children-ux-physical-development/ | ✅ |
| Kids' hit areas (BBC GEL, archived 2016) * | "minimum 64px (based on a medium density screen) 9.6mm" | https://www.bbc.co.uk/gel/features/how-to-design-for-children | ✅ (archived page) |
| BBC children's games framework * | text minimum 15px; under 24 px needs 4.5:1, 24 px and over 3:1; use icons or patterns as well as colour | https://www.bbc.co.uk/gel/features/games-framework | ✅ |
| Children's touch accuracy (Anthony et al. 2013) * | ages 7 to 10 "miss an average of 30% of the small (0.25")" targets (6.35 mm); edge padding nearly doubled misses | https://lisa-anthony.com/wp-content/uploads/2013/04/anthony-et-al-jpuc2013.pdf | ✅ |
| Font size for ages 9 to 11 (Bernard et al. 2002) * | 14 pt and sans serif "perceived as being the easiest to read"; no speed difference (abstract only) | https://portfolio.erau.edu/en/publications/examining-childrens-reading-performance-and-preference-for-differ/ | ✅ |
| Bigger is not always better (Katzir et al. 2013) | a 20% smaller font lowered comprehension for 2nd graders but raised it for 5th graders | https://pmc.ncbi.nlm.nih.gov/articles/PMC3777945/ | ✅ |
| A kids-specific contrast ratio above 4.5:1 | not found | | ❌ |

**For the HUD:** body text at least 28 px at 1080p (scale with DPI on phones), contrast at least 4.5:1 measured against the busiest part of the 3D scene behind it, meter outlines and icons 3:1, touch targets about 2 cm (76 CSS px; our arithmetic at 96 px per inch) with the platform minimums (44 pt, 48 dp) as the floor. Every one of these is a minimum.

---

## C. Far backdrop: Mount Sharp and the rim 🏔️

| Item | Value | Source URL | Status |
|---|---|---|---|
| Landing site | "4.6 degrees south latitude, 137.4 degrees east longitude, near base of Mount Sharp inside Gale Crater" | https://www.jpl.nasa.gov/news/press_kits/MSLLanding.pdf | ✅ |
| Bradbury Landing, exact | 4.5895° S, 137.4417° E (Wikipedia; no NASA page with this precision found). Used for the numbers below | | ⚠️ |
| Gale and Mount Sharp | crater "96 miles (154 kilometers) in diameter"; Mount Sharp "rising about 3 miles (5 kilometers) above the crater floor" | same | ✅ |
| **MOLA MEGDR 128 px/deg** (about 463 m per pixel) | tile `megt00n090hb.img` covers 0° to 44° S, 90° to 180° E: 5,632 lines × 11,520 samples, 16-bit big-endian, metres above the areoid; 129,761,280 bytes. The server accepts HTTP Range | https://pds-geosciences.wustl.edu/mgs/mgs-m-mola-5-megdr-l3-v1/mgsl_300x/meg128/ | ✅ |
| MEGDR small crop | done: one Range request for lines 385 to 896 (3° to 7° S, all longitudes) = 11.8 MB. Fetching only 2.5° of longitude per line would be 128 requests of about 0.6 KB each. No GDAL needed: plain `int16` rows | `scripts/mola-horizon.py`, `pages/backdrop/` | ✅ (tested) |
| MOLA licence | Astropedia lists "MOLA (CC0)" | https://astrogeology.usgs.gov/search/map/mars_mgs_mola_mex_hrsc_blended_dem_global_200m | ✅ |
| HRSC/MOLA blended DEM, 200 m | 11,384,463,908 bytes (11 GB), HTTP Range works. **Licence trap:** HRSC part is CC BY-SA 3.0 IGO (share-alike), "Please cite authors" | same, file at https://planetarymaps.usgs.gov/mosaic/Mars/HRSC_MOLA_Blend/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2.tif | ✅ |
| MOLA global DEM 463 m (GeoTIFF) | 2,125,771,142 bytes, HTTP Range works. Not needed: the MEGDR tile above is the same data in a simpler format | https://planetarymaps.usgs.gov/mosaic/Mars_MGS_MOLA_DEM_mosaic_global_463m.tif | ✅ size |
| Landing site height | MOLA: −4,503 m (3×3 mean −4,502 m). The HiRISE DTM nearby: −4,491 to −4,493 m | MEGDR, computed | ⚠️ our arithmetic |
| Mount Sharp summit (highest MOLA cell) | 5.371° S, 137.855° E, +787 m: **5.29 km above the landing site, 52.4 km away, bearing 152° (SSE)** | MEGDR, computed | ⚠️ our arithmetic |
| The summit is hidden | from the landing site the summit sits 5.4° above the horizon, but the mountain's flanks 15 to 20 km away rise 2.2 to 4.2 km and reach 6° to 12°. The skyline from SE to S is Mount Sharp's lower slopes, highest at bearing 135° (12.4°) | `pages/backdrop/mola-horizon-ring.txt` | ⚠️ our arithmetic |
| North rim | bearing 0°: skyline 29.5 km away, 2.13 km above the landing site, 3.9° above the horizon. NW to NE (300° to 30°): 25 to 37 km, 1.5 to 2.6 km above, 3.2° to 4.0° | same | ⚠️ our arithmetic |
| West and south-west | 270°: 40 km, 2.4 km above; 225° to 240°: the far south-west rim, 68 to 79 km, about 3.2 km above, 1.7° to 2.1° (the ray stops at 80 km, so it may reach farther) | same | ⚠️ our arithmetic |
| East | 90°: a low rise 19 km away, 0.9 km above, 2.5° | same | ⚠️ our arithmetic |

How the ring was made: for every bearing, walk out from the landing site in 0.25 km steps to 80 km, subtract the planet's curvature (d²/2R, R = 3,396 km), and keep the point with the highest angle above the horizon. The full 15° table is in `pages/backdrop/mola-horizon-ring.txt`. **For the backdrop mesh:** a ring at 20 to 80 km whose top edge follows those angles; at a 463 m grid, the crop around the crater is about 300 × 300 samples.

---

## D. The terrain file on disk 🗺️

| Item | Value | Source URL | Status |
|---|---|---|---|
| Where it comes from | `3D Printing/Curiosity Landing Site/Curiosity Landing Site.stl`, 2,756,784 bytes (same as ours), with a preview PNG | https://github.com/nasa/NASA-3D-Resources/tree/master/3D%20Printing/Curiosity%20Landing%20Site | ✅ |
| What NASA says about it | the catalogue page says only "Part of NASA's Mars Science Laboratory mission". **No units, scale, area, data source or vertical exaggeration** | https://science.nasa.gov/3d-resources/curiosity-landing-site/ | ✅ (absence) |
| Licence | repo README: "free and without copyright"; meta.json: "NASA Open Source Agreement Version 1.3" | https://github.com/nasa/NASA-3D-Resources | ✅ |
| File contents | binary STL "Exported from Blender-2.69", 55,134 triangles; a regular height grid of 192 × 141 points, spacing 3.986 units (761 × 558 units), heights 0.13 to 34.18 units in 0.129-unit steps, 856 grid cells missing (a corner), a base 6.6 units deep | `pages/terrain/stl-measurements.txt` | ✅ measured |
| What area it covers | the preview and our height image show one large crater with a central mound: Gale and Mount Sharp, with the plains around them. It is the whole region, not the landing ellipse | preview PNG, `scripts/stl-grid.py` | ⚠️ our reading |
| Horizontal scale | crater rim to rim 335 to 343 units. Taking Gale = 154 km gives about 0.45 km per unit (0.43 if our rim pick runs 5% wide, as it did on the Gale Crater STL). So the tile is about 330 to 350 km × 240 to 255 km, and one grid cell is about 1.8 km | measured | ⚠️ our arithmetic |
| Vertical scale | Mount Sharp's top stands about 32 units above the lowest floor, about 14 km at that scale, against 5.3 km in MOLA: an exaggeration of roughly 2.5 to 3×. Not stated by NASA | measured | ⚠️ our arithmetic |
| Orientation | the low floor sits on the model's −Y side; on Mars the low floor (where Curiosity landed) is north of Mount Sharp, so −Y is probably north. Check against a map before placing the sun | measured | ⚠️ our reading |
| Sister file "Gale Crater.stl" | 26,317,184 bytes: "3x vertical exageration derived from data collected by the HRSC camera onboard the ESA's Mars Express mission", 11 cm across = about 200 km, "1 cm = 19 km". Credit: K. Gwinner, J. Oberst, R. Jaumann, G. Neukum, ESA/DLR/FU Berlin. HRSC origin: check its licence before use | https://science.nasa.gov/3d-resources/gale-crater/ | ✅ |
| **HiRISE DTM for the play area (tested)** | `DTEEC_023957_1755_024023_1755_U01` (the brief's pick): the landing point falls in its no-data margin; a 400 m window there returned no data. `DTEEC_018854_1755_018920_1755_U01` (156,211,149 bytes, CC0, 1.01 m/px) covers it, but its valid area ends about 30 m east of the landing point | https://astrogeo-ard.s3-us-west-2.amazonaws.com/mars/mro/hirise/controlled/dtm/ESP_018854_1755_ESP_018920_1755/DTEEC_018854_1755_018920_1755_U01.tif | ✅ tested |
| A full 400 × 400 m crop | centred 200 m west of Bradbury (4.5895° S, 137.4383° E): 395 × 396 px, no gaps, heights −4,495.5 to −4,489.4 m (6 m of relief: the floor here is flat). Fetched 0.9 MB in 4 tiles | `pages/backdrop/hirise-018854-window.txt` | ✅ tested |
| How, without GDAL | the COG is BigTIFF, 512 px tiles, deflate with predictor 2 (integer differencing on the float bits), equirectangular on a 3,396,190 m sphere. `scripts/cog-window.py` reads the header with one Range request, then only the tiles it needs (Python 3 + numpy + zlib) | `scripts/cog-window.py` | ✅ tested |

**What this means:** the STL is good for the far backdrop only if the height is divided by its unknown exaggeration and it is rotated by eye. MOLA gives true heights and directions from the same small download, so the backdrop should come from MOLA. The play patch should come from the HiRISE crop, shifted west of Bradbury as above.

---

## Candidate factcheck rows

1. A NASA surface habitat test unit (HDU PEM) was a 5 m wide, 3.5 m tall cylinder of nearly 12,000 kg with four wall hatches. ✅ NTRS 20110011015, 20110013501.
2. NASA's crewed rover concept (SEV): 4.48 m long, 3.05 m tall, 0.99 m wheels, 2,994 kg, crew of two (four in an emergency), about 10 km/h, wheels pivot 360°. ✅ NASA SEV fact sheet FS-2011-08-045-JSC.
3. Curiosity: 3.0 × 2.8 × 2.1 m, 0.5 m wheels, 899 kg. ✅ MSL launch press kit.
4. A suited astronaut needs a door about 1.5 m tall and 1 m wide and can step up 0.3 m comfortably. ✅ NTRS 20250004496.
5. A suited crew member is about 1 m wide (99th percentile). ✅ NTRS 20090032975.
6. Suited work is easiest at about 1.1 m above the ground; reaching the ground is hard. ✅ NTRS 20090032975.
7. ISS cargo bags (CTB) are about 50 × 42 × 25 cm, and NASA has proposed reusing them as storm-shelter walls. ✅ NTRS 20160002631, 20160004371.
8. DRA 5.0 Mars solar arrays: wings 2.5 m high × 58 m long, tilted 30°, 5 kWe per module. ✅ DRA 5.0 Addendum.
9. A Mars base antenna in DRA 5.0 is a 6 m inflatable or deployable dish (1 m on the Moon). ✅ DRA 5.0 Addendum Table 7-9.
10. From the landing site, Gale's north rim stands about 30 km away and 2 km higher. Mount Sharp's summit is 52 km away and 5.3 km higher, hidden behind its own flanks. ⚠️ our arithmetic from MOLA MEGDR.
11. Gale is 154 km across, and Mount Sharp rises about 5 km above the floor. ✅ MSL landing press kit.
12. Children aged 7 to 10 miss 30% of 6 mm touch targets; NN/g recommends 2 × 2 cm targets for young children. ✅ Anthony et al. 2013; NN/g 2018.

## Not found or left out ❌
- Width and turning radius of the SEV; size of its suitport opening.
- HDU and DRA 5.0 habitat hatch sizes; DRA 5.0 habitat dimensions; Foundation Surface Habitat dimensions.
- Standing height of any crewed Mars lander; Starship's height from a page we could save.
- Suited height and helmet size; Curiosity's high-gain antenna diameter.
- A NASA page giving Bradbury Landing to four decimals.

## Files
- `pages/sizes/`: NTRS papers (PDF + text; PDFs over 2 MB kept as text only), the SEV fact sheet, MSL press kits (text), and verbatim excerpts of two large PDFs that are not stored (`nasa-hidh-rev1.excerpt.md`, `nasa-dra5-addendum.excerpt.md`).
- `pages/hud/`: accessibility pages and papers.
- `pages/backdrop/`: MEGDR label and directory listing, Astropedia page, HTTP headers with file sizes, the horizon ring table, the HiRISE window test.
- `pages/terrain/`: the NASA 3D Resources pages, repo README, meta.json and file tree, both preview images, STL measurements.
- `scripts/`: `mola-horizon.py`, `cog-window.py`, `stl-grid.py` (each has its usage on line 1).

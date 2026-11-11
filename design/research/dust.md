# Footstep and wheel dust at Gale: the numbers

Written 12 Nov 2026 after the playtest note "the footstep dust is not realistic". It is the Mars input for `tooling/skills/ground-contact-fx`. Sources are saved in `pages/dust/` (`physics/`, `games/`, `godot/`). Status: ✅ seen in the saved source (kwic), ⚠️ inferred or reported, ❌ not found.

**Short version:** a boot on Mars throws a low spray of grains that lands within half a second and well under a shin high, plus, on a dusty coat, a faint haze a few cm thick that stretches downwind and is gone in 2 to 3 s. It leaves a print a few per cent darker. The round puffs at knee height that hang for 3 s are wrong on every count.

## What is wrong with `world/dust.gd` puffs now
- `gravity = Vector3.ZERO` with a 0.5 to 0.7 m quad growing 4 times over 3 s, aimed partly upward: a ball that rises and hangs. Nothing in the sources hangs at knee height.
- It was built from the Ingenuity line "became diffuse within seconds" (`research/godot-build/movement-and-look.md` §4), but that cloud came from rotor downwash and stayed in the bottom ~5 cm. It says nothing about sand grains, which a boot throws most of.
- Radial dot texture, 8 large blended quads: the overdraw shape the PowerVR guide warns about.

## Numbers
| Claim | Value | Source (file) | Status |
|---|---|---|---|
| Gravity | 3.71 m/s² (0.378 g) | Kok 2012 Table 2.3 (`physics/kok2012-...txt`) | ✅ |
| Grain classes | long-term suspension < ~20 µm; short-term ~20–70 µm; saltation ~70–500 µm; bigger "settle back ... after a short hop" | Kok 2012 | ✅ |
| Fine dust stays up | "up to several weeks" (in the atmosphere, wind-lifted) | Kok 2012 | ✅ |
| Typical saltation hop, 250 µm sand | Mars ~10 cm high, ~100 cm long; Earth ~3 cm, ~30 cm | Kok 2012 Table 2.3 (model) | ✅ (model value) |
| Conflict | Almeida 2008: Mars hops "100 times higher and longer"; Kok: that neglects splash | `physics/almeida2008-*` | ⚠️ conflicting; use Kok |
| Launch angles | rebound "~30 – 45º", splash "~40-60 degrees", typical launch ~35° (Earth wind-blown sand) | Kok 2012 | ✅ (Earth, wind-driven; a boot is assumed similar) ⚠️ |
| Boot kick arc on Mars | at 1 m/s, 45°, no drag: 0.38 s aloft, 6.7 cm high, 0.27 m away | `T=2v·sinθ/g`, `H=(v·sinθ)²/2g` | ⚠️ inferred; 1 m/s foot speed is an assumption (walk ~1 m/s, `movement-and-look.md`) |
| Same kick on Earth / Moon | Earth 0.14 s, 2.5 cm; Moon 0.87 s, 15 cm | same formulas | ⚠️ inferred |
| Settling speed of fine dust (Stokes with slip, 636 Pa) | r = 1.4 µm ≈ 2.5 mm/s; d = 20 µm ≈ 3.3 cm/s | agent maths, checked by a second run | ⚠️ inferred |
| Lifted dust cloud: start | "The initial expansion was 4–6 m/s within the bottom ∼5 cm of the atmosphere" (rotor-driven) | Lemmon 2022 (`physics/lemmon2022-...txt`) | ✅ |
| Lifted dust cloud: spread | "expanded initially in all directions regardless of wind"; "Within 2–3 s, the clouds elongated downwind with diffuse boundaries" | Lemmon 2022 | ✅ |
| Cloud thins | "drifted away and became diffuse within seconds" (dilution, not settling) | Lemmon 2022 | ✅ quote, ⚠️ "dilution" is inferred |
| Mark contrast | removing dust: "2%–3% darker" and "3%–4% darker"; dust-devil tracks ~2.5% | Lemmon 2022 | ✅ |
| Rover tracks from orbit | "the tracks appear darker where the rover's wheels disturbed the top layer of dust"; under the dust: "darker basaltic sands" | HiRISE PIA16141, 2012 (`physics/pia16141-...html`) | ✅ |
| Dust colour | "reddish surface dust" over darker sand; rock under the dust grey (`movement-and-look.md`) | PIA16141 | ✅ |
| Moon, for contrast | rover dust "followed ballistic trajectories"; no fender extension = "massive 'rooster tails'"; trampled soil 15–30% darker | LASP 2012, NASM 2015, Clegg 2014 | ✅ |
| Dust raised by Curiosity or Perseverance wheels | no image or paper of a wheel dust cloud found; captions show tracks only | | ❌ not found |
| Rover dust angles, heights | not measured anywhere found (Hsu and Horányi 2012 is paywalled) | | ❌ not found |
| Footstep in dry sand on Earth | no source | | ❌ not found |

## For the reality sheet
Rows the lane needs (values from the table): `g` 3.71; foot speed at contact (assumed ~1 m/s, ⚠️ measure it from the walk clip); launch angle 30–60°; grit height ≤ ~7 cm and life ≤ ~0.4 s at a walk; haze only on the dust coat, ≤ ~5 cm at the start, life 2–3 s, drifting at the wind row's speed; print 2–4% darker. A rover wheel: grit at the tread speed backward from the contact patch, kept low by its fenders; no sourced plume height.

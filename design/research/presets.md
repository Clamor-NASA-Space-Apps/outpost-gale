# Quality presets: who each one is for, and why each value

Written 13 Nov 2026 for `DESIGN.md` `quality`. The costs come from the 12 Nov profile (`tests/profile_run.gd`,
summed up in `design/handoff/session.md` and commit e0e2ebf) and from `performance.md`. Only `phone` has been played
on its device (the Galaxy A16). The other four are reasoning from those costs until someone plays them on the
hardware named.

**TL;DR.** Pixels and MSAA are the big costs, so they climb fastest from preset to preset. Shadows stay at one or
two splits until `max`, because every shadowed light draws each lit object twice. Anything marked "recompile" is a
2 to 3 s shader compile on the web, so it only changes when the player picks a preset, behind the cover.

## 1. What we measured 📏

| Cost | Number | Where |
|---|---|---|
| GPU frame on the old `high`, window maximized | 14.3 ms, of it 4x MSAA 6.4 ms and the ground shader 5.2 ms | profile, 12 Nov |
| A16 on the old `low` | about 20 fps with stutters, then a steady 35 to 45 fps after the 0.6 Mpx budget, the wrapping trail map, the shader warm-up, the lighter ground and 3 physics steps at most | e0e2ebf |
| A shader compile on the web | 2 to 3 s per preset switch (no shader cache in the web build) | profile, `performance.md` 3.2 |
| A shadowed sun | a second full draw of every lit object (read from the GLES3 source, not timed) | `performance.md` 3.1 |
| Trail map | 1 byte a pixel: 1024 px is 1 MiB, 2048 px is 4 MiB; only changed tiles upload now | `performance.md` 3.3 |

## 2. The presets 🎚️

| Knob | phone | older | laptop | gaming | max |
|---|---|---|---|---|---|
| Hardware | Galaxy A16 class phones | Intel HD, 6th to 8th gen | Iris Xe, UHD | a graphics card | the best you have |
| `msaa` | 0 | 0 | 2 | 4 | 8 |
| `pixels` (Mpx) / `scale` | 0.6 | 0.8 | 1.4 | native (`scale` 1) | native |
| `shadows` splits | 1 | 1 | 2 | 2 | 4 |
| `shadowMap` | 1024 | 1024 | 2048 | 4096 | 4096 |
| `shadowRange` (m) | 25 | 25 | 60 | 60 | 60 |
| `shadowFilter` | 2 | 2 | 3 | 4 | 5 |
| `glow` | 0 | 0 | 0.4 | 0.5 | 0.5 |
| `ssao` | off | off | off | off | on |
| `detail` | off | off | texture | texture | texture |
| `aniso` | 1 (2x) | 1 | 2 (4x) | 3 (8x) | 4 (16x) |
| `ground` | flat | cheap | full | full | full |
| `particles` | 0.5 | 0.5 | 0.75 | 1 | 1 |
| `trail` (px) | 1024 | 1024 | 2048 | 2048 | 2048 |
| `lamps` lit | 2 | 2 | 4 | all | all |

## 3. Why 🔍

- **phone:** the values that took the A16 from 20 to 35 to 45 fps. 0.6 Mpx is Modern Warfare 2's 1024x600 on
  consoles (`performance.md` A3). No MSAA: at 6.4 ms on a laptop GPU it is the single biggest cost we timed.
  The flat ground skips the ground shader's photo sets, the other big one (5.2 ms).
- **older:** a 6th to 8th gen Intel HD has more fill rate than the A16 but the same small memory bandwidth, so it
  gets a third more pixels (0.8 Mpx) and the `cheap` ground (one photo scale), and keeps everything else of `phone`.
- **laptop** (desktop start): Iris Xe roughly doubles UHD's shader units, so 1.4 Mpx (about 1600x900) with 2x MSAA,
  the console mix (A3), and the photo surfaces Ravindu asked for on 12 Nov (`detail: texture`, `ground: full`). Two
  shadow splits so the base's shadows hold up to 60 m. On a plain UHD laptop that is slow, `older` is one step down.
- **gaming:** a graphics card has room for native resolution, 4x MSAA and a 4096 shadow map; a softer PCF
  (`shadowFilter` 4) because the bigger map shows the steps of a hard one.
- **max:** 8x MSAA, 4 splits (casters drawn twice as often as 2), the softest filter and SSAO (cheaper since 4.6,
  B13, still unmeasured here). For screenshots and strong cards, not a target.

## Open questions ❓
- None of `older`, `laptop`, `gaming` or `max` has been timed on its hardware; play each for five minutes on one
  before trusting it.
- Whether 2x MSAA at 0.6 Mpx beats none at a higher pixel count on a phone (`performance.md` open questions).

# Rover body on its springs, and the radio (excerpts)
Fetched 2026-11-12 for the "more life" lane (roadmap: rover roll, radio squelch). Quotes verbatim unless marked "summary".

## Ride frequency (how fast a body bobs on its springs)
- OptimumG, "Springs & Dampers, Tech Tip 1" (Claude Haney / OptimumG): summary from search results, the PDF's
  certificate had expired: passenger cars 0.5 to 1.5 Hz, higher for race cars; the figures "were originally
  developed for passenger cars". https://www.optimumg.com/docs/Springs&Dampers_Tech_Tip_1.pdf
- The usual relation: f = (1 / 2 pi) sqrt(k / m), and with a static sag d = m g / k, f = (1 / 2 pi) sqrt(g / d).
  A Mars rover sprung for the same sag as an Earth car bobs sqrt(3.71 / 9.81) = 0.61 times as fast:
  0.5 to 1.5 Hz becomes 0.31 to 0.92 Hz (our derivation, not a measured rover number).

## Roll gradient (degrees of body roll per g of sideways acceleration)
- OptimumG "Springs & Dampers, Tech Tip 2" (Matt Giaraffa), summary from search results: 0.2 to 0.7 deg/g for stiff
  high-downforce cars, 1.0 to 1.8 deg/g for low-downforce sedans (the Millikens' target range for sedans).
  https://www.scribd.com/doc/115193008/OptimunG-Springs-Dampers-Tech-Tip-2
- No published roll gradient for an SUV, a truck or a crewed rover was found. A tall cab on long-travel off-road
  suspension rolls more than a sedan: our value sits above the sedan range and is art direction.
- Roll angle = m a h / K_roll, and a spring sized for the same sag under Mars weight has K about m g: so the roll
  goes with a / g of the planet the rover is on (our derivation). On Mars the same turn rolls the body 2.6 times
  as far as on Earth.

## Damping
- Forum citations of Milliken (summary, not checked in the book): about 0.15 of critical for best ride in a compact
  passenger car, about 0.45 for best roadholding. https://www.physicsforums.com/threads/what-is-the-ideal-damper-for-a-passenger-car-suspension.805751
- Our value is a little under critical (art direction): one small overshoot that settles, the "follow through" of
  skills/living-atmosphere section 4.

## Radio: Quindar tones (Apollo)
https://en.wikipedia.org/wiki/Quindar_tones (WebFetch)
- "both being pure sine waves that were 250ms long."
- "The "intro tone" was generated at 2,525 Hz and signaled the "key down" key-press of the PTT button and unmuted the audio."
- "The "outro tone" was slightly lower at 2,475 Hz and signalled the release of the PTT button and muted the audio."
- Mission Control talks to spacewalkers "fairly regularly" (Reisman, in design/research/alive.md section 2).

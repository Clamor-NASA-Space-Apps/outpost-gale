# How high a rover's wheels climb (saved 13 Nov 2026)

1. NASA/JPL, Mars Science Laboratory fact sheet (REV 141119),
   https://solarsystem.nasa.gov/docs/MSL%20Fact%20Sheet%20REV-141119.pdf (text in `jpl-msl-factsheet-rev141119.txt`):
   > "JPL ... engineered Curiosity to roll over obstacles up to 65 centimeters (25 inches) high and to travel up to
   > about 200 meters (660 feet) per day on Martian terrain."
   Curiosity's wheels are 0.5 m across (MSL launch press kit, `../sizes/jpl-MSLLaunch.txt` line 167): 65 cm is 1.3 wheel diameters, with a rocker-bogie.
2. Planetary Society, Curiosity wheel damage (Lakdawalla), https://www.planetary.org/articles/08190630-curiosity-wheel-damage:
   the rocker-bogie "keeps the rover body relatively level even when the wheels are climbing obstacles equal to their heights".
3. University of Maryland ENAE 788X, "Case Study: Lunar Roving Vehicle" (D. Akin, 2018), slide 47 "LRV Terrain Design Cases":
   https://spacecraft.ssl.umd.edu/academics/788XF20/788XF20L05.LRVx.pdf
   > Crevasse crossing capability 70 cm; Step obstacle climbing capability 35 cm; Clearance under chassis 35 cm
   The LRV's tyres are 81.8 cm across (NSSDC, https://nssdc.gsfc.nasa.gov/planetary/lunar/apollo_lrv.html): a 35 cm step
   is 0.43 wheel diameters on a plain wishbone suspension.
4. NASA SEV fact sheet FS-2011-08-045-JSC (`../sizes/nasa-sev-factsheet-2011.txt`): lists "Active Suspension" among its
   technologies, wheels "4.7x39 inches in diameter". No obstacle height given.

For the SEV's 0.99 m wheels that is 0.43 x 0.99 = 0.43 m (LRV-like suspension) to 1.3 x 0.99 = 1.29 m (rocker-bogie).

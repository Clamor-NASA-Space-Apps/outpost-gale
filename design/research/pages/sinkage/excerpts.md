# How far loads sink into Mars ground (12 Nov 2026, for reality.json ground.sink.* and rock.embed)

usgs.gov answers curl with a 919-byte block page, so these were read through a fetch tool, quoted as given.

1. Moore, H.J. et al. 1987, "Physical properties of the surface materials at the Viking landing sites on Mars",
   USGS Professional Paper 1389. Abstract: https://www.usgs.gov/publications/physical-properties-surface-materials-viking-landing-sites-mars
   - "Footpad 2 of Lander 1 penetrated drift material 0.165 m, and footpad 3 penetrated blocky material 0.036 m." (seen)
   - Drift material: cohesion 0.7 to 3.0 kPa; blocky material 1.5 to 16 kPa; crusty to cloddy 0.5 to 5.2 kPa. (seen)
2. Arvidson, R.E. et al. 2017, "Mars Science Laboratory Curiosity Rover Megaripple Crossings up to Sol 710 in Gale
   Crater", J. Field Robotics. https://authors.library.caltech.edu/76994
   - "sinkage values up to approximately 30% of the 0.50 m wheel diameter" in megaripples. (seen in the abstract)
3. Arvidson, R.E. et al. 2014, "Terrain physical properties derived from orbital data and the first 360 sols of
   Mars Science Laboratory Curiosity rover observations in Gale Crater", JGR Planets 119, doi:10.1002/2013JE004605
   - "<1 cm sinkage" on the hummocky plains and bedded fractured surfaces. (⚠️ a search summary of the abstract;
     the PDF at deepblue.lib.umich.edu did not open)
4. Rocks partly buried: no measured buried share found. Viking 1 imaging describes a block "partly buried by
   sediment" (NASA SP-425 ch. 21, https://solarviews.com/history/SP-425/ch21.htm, ⚠️ search summary only), so
   rock.embed is an estimate.

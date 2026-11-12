# Sound and music in games: what the makers say (excerpts)
Fetched 2026-11-12. Method per source. Quotes verbatim unless marked "summary".

## Journey: Steve Johnson, "The Sound Design of Journey", Game Developer, 10 Oct 2012
URL: https://gamedeveloper.com/audio/the-sound-design-of-i-journey-i- (WebFetch)
- "The robe and scarf loops are always reading a few variables from code."
- "They take into account player velocity, wind speed, and for the scarf, scarf length."
- "So each scarf loop is always playing one of 64 specific arrangements of scarf sounds."
- Flight wind: "Their volumes scale with player velocity."
- "Left steps were distinguished from right steps for a back-and-forth sound."
- "In the snowstorm mountain level alone there are 16 different ambiences for the various areas and wind intensities."
- "I tried to make sound alive and breathing in a sinister, mysterious way."
- "For every cloth strand you see there are always multiple little grains of sound trying to play."
- "At first they played all of their sounds at random and seemed pretty dumb and robotic."
- "Austin noticed a bass tone I had used in the transitions was blowing out small TV speakers."

## Journey: Austin Wintory, The Sixth Axis interview, 15 Mar 2012
URL: https://www.thesixthaxis.com/2012/03/15/interview-journey-composer-austin-wintory/ (WebFetch)
- "Musically it's like a big cello concerto where you are the soloist" and "all the rest of the instruments represent the world around you, including other players"
- "The goal of course was to make it totally seamless, so that it feels like the music is unfolding in real time, as if being written by an unseen (and very fast!) composer"
- On sound effects and music: "I think they're equals in terms of the overall mix ... but the scope of the sound effects is generally pretty subtle." "the sound design is there to really make the world feel tactile and real."

## Journey: Jenova Chen at GDC 2013, reported by Game Developer staff, 3 May 2013
URL: https://gamedeveloper.com/audio/video-designing-a-new-emotional-experience-in-i-journey-i- (WebFetch)
- "music is the most effective and powerful medium that can create emotion."
- "Prototyping for the emotional Journey actually began around its music."

## Halo: Marty O'Donnell, Q&A with the HBO forum ("Hedge"), 2002
URL: https://halo.bungie.org/misc/hedge_martyinterview.html (curl)
- "Ambient sound is one of the main ways to immerse people psychologically. A dark room is spooky, but add a creaking floorboard and rats skittering in the walls and it becomes really creepy."
- "Life isn't silent, but you are always gating the sounds around you. Games that have sounds that skip, drop out, or have periods of silence tend to lose my attention."

## No Man's Sky: Paul Weir Q&A, Audiokinetic blog (Anne-Sophie Mongeau)
URL: https://www.audiokinetic.com/en/blog/behind-the-sound-of-no-mans-sky-a-qa-with-paul-weir-on-procedural-audio/ (live page 403; read the Wayback copy of 8 Nov 2024 with curl)
- "From the beginning, I aimed to keep the ambiences as natural as possible, using lots of original recordings of weather effects and nature sounds."
- "you need to pass as much information as practical from the game to the audio systems in order to understand the environment and state of play. For example, what planet biome you're on, what the weather is doing, where you are relative to trees, water or buildings, whether you're close to a cave or in a cave, underwater, in a vehicle"
- "We have a control value ... for 'storminess' and know whether the player is indoors or out. It was a simple job then to add different audio, such as shakes and creaks, when indoors and a storm is raging"
- "Whilst there's a lot of randomisation in the game, I always know the upper and lower limits of any sound"
- On synthesising wind: "I'm not generally in favour of using it to create wind or rain effects ... Wind can be cold, gentle, spooky, reassuring. There are complex qualities that we instantly react to with natural sounds, it's a lot harder to do this with synthetic sound."

## Hellion (a space survival game): "Sounds from Outer Space", Audiokinetic blog
URL: https://www.audiokinetic.com/en/blog/sounds-from-outer-space-hellion-game/ (live page 403; Wayback copy of 8 Nov 2024 via curl)
- "In a vacuum, there is no air or medium for sound waves to travel; therefore, the only way to hear anything is either through direct impact or via vibrations when in contact with a solid object."
- "Simply low passing or equalizing the sound would not sound good enough." (they used impulse responses through materials)
- "a Wwise Atmosphere parameter was created and then the programmer connected it to the game's air pressure parameter ... This parameter controls equalizers, distortion effects, convolution reverbs, bus volumes, voice volumes"
- "the less the air pressure, the smaller the max distance would be in the distance attenuation. Basically, when in a vacuum, all that players can hear are muffled sounds of objects that are in very close proximity."
- "if players have no helmet or keep the visor open in the vacuum, they won't hear anything but their own heartbeat and muffled chocking."
- A parameter "to make UI and character breathing sounds slightly louder" with the visor closed.
- "The sound of a character moving is separated into three parts: Footsteps Type, Suit Type, and Weapon Type."
- "the life support system is made out of air generators, nodes, and air filters, which all combined in layers will make up the general ambience of a room."

## Dead Space (remake): EA Motive, "Focus on Dead Space audio design" (no date shown, about March 2022)
URL: https://www.ea.com/ea-studios/motive/news/focus-on-deadspace-audio-design (WebFetch)
- "the system that controls Isaac's heart rate, breathing, and dialogue delivery" (A.L.I.V.E.)
- "how audio levels will be controlled through different materials and surfaces as well as projected audio down hallways." (occlusion)

## Death Stranding: 505 Games developer Q&A, 21 Sep 2020
URL: https://deathstrandingpc.505games.com/en/?p=7726 (WebFetch)
- Yoshiike: "have Sam lean or sway, and then readjust his balance, based on changes in cargo weight."
- Sound team via Sakamoto: "sounds that one normally wouldn't think of, such as the sound of wind hitting against Sam's body."

## What a spacewalker hears
- Garrett Reisman (Quora via Slate, 14 Oct 2013): https://www.slate.com/blogs/quora/2013/10/14/what_sounds_do_astronauts_hear_during_a_spacewalk.html (WebFetch)
  - "Mostly what you hear is the sound of the pumps and fans that circulate air and water through your suit."
  - not "the silent lonely environment with no sound other than your own breathing" of the movies
  - "the folks in Mission Control talking to you fairly regularly"
  - after the hatch closes: "You can see their equipment bumping into stuff as before, but now it is silent."
  - inside the station during a spacewalk: "you can hear the spacewalkers bumping and clanging along", like "ghosts in the attic dragging chains."
- Nadia Drake, National Geographic, 14 Apr 2015: https://www.nationalgeographic.com/science/article/a-behind-the-scenes-look-at-that-amazing-gopro-footage-from-space (WebFetch)
  - "there's a persistent humming and clanking accompanying both spacewalks."
  - NASA: "the sound of the spacesuit's fan, which circulates air and also drives the water pump and water separator."
  - Dan Huot (NASA): "So, the vibrations just carried through the system."

## Breath of the Wild (search summaries, pages not saved)
- Hajime Wakai: piano as the main instrument "was meant to accentuate ambient sounds"; field music "would sometimes fade completely, leaving only ambient nature sounds" (critic's description). Nintendo Everything: https://nintendoeverything.com/breath-of-the-wild-composers-on-changing-up-zeldas-music-formula-and-more
